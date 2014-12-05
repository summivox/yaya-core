{sin, cos, tan, abs, sign, sqrt, atan2, hypot, min, max, PI} = M = Math
N = require 'numeric'
assert = require 'assert'
util = require 'util'
svgPath = require 'svg-path'
_ = require 'lodash'

SE2 = require './se2'
{aabb, cbz, intersection} = require './geom'

print = (x) -> console.log util.inspect x, color: true, depth: null

# some math shorthands (yadda, I know they belong to a library)
plus = ([x1, y1], [x2, y2]) -> [x1+x2, y1+y2]
minus = ([x1, y1], [x2, y2]) -> [x1-x2, y1-y2]
scale = ([x1, y1], k) -> [x1*k, y1*k]
neg = ([x, y]) -> [-x, -y]
cross = (a, b) -> a[0]*b[1] - a[1]*b[0]
dot = (a, b) -> a[0]*b[0] + a[1]*b[1]
rot90 = ([x, y]) -> [-y, x]
norm = ([x, y]) -> hypot(x, y)
norm2 = ([x, y]) -> x*x + y*y
normalize = ([x, y]) ->
  k = hypot(x, y)
  [x/k, y/k]

# take the "average" of left-right contact normals
avgNormal = (nl, nr) ->
  k = dot(nl, nr)
  if k >= 0
    normalize N.add(nl, nr)
  else
    normalize minus(nl, nr)

module.exports = class Boundary
  constructor: (@pathStr, scale = 1) ->
    if this not instanceof Boundary then return new Boundary pathStr
    k = 1/scale

    # pre-process with svg-path:
    #   parse, relative to absolute, arc to cubic
    sp = svgPath pathStr
    sp.abs()
    sp.convertArcs()
    p = sp.content

    # initial M: starting point of loop
    # missing: implicit start at origin
    if p[0].type == 'M'
      @start = p[0]
      p.shift()
    else
      @start = {x: 0, y: 0}

    # simplify all segments into L/C:
    #   H, V, Z -> L
    #   T -> Q (-> C)
    #   S -> C
    prev = @start
    for seg in p
      switch seg.type
        when 'M'
          throw new Error "yaya: Boudndary: broken path"
        when 'H'
          seg.type = 'L'
          seg.y = prev.y
        when 'V'
          seg.type = 'L'
          seg.x = prev.x
        when 'Z'
          seg.type = 'L'
          seg.x = @start.x
          seg.y = @start.y
        when 'T'
          seg.type = 'Q'
          if prev.type == 'Q'
            seg.x1 = prev.x*2 - prev.x1
            seg.y1 = prev.y*2 - prev.y1
        when 'S'
          seg.type = 'C'
          if prev.type == 'C'
            seg.x1 = prev.x*2 - prev.x2
            seg.y1 = prev.y*2 - prev.y2
          else
            seg.x1 = prev.x
            seg.y1 = prev.y
      prev = seg

    # reason for 2nd pass: T need to see if previous segment is Q or T
    # converting T to C in one pass would lose this information
    prev = @start
    for seg in p
      if seg.type == 'Q'
        seg.type = 'C'
        xx = seg.x1*2/3
        yy = seg.y1*2/3
        seg.x1 = prev.x / 3 + xx
        seg.y1 = prev.y / 3 + yy
        seg.x2 = seg.x  / 3 + xx
        seg.y2 = seg.y  / 3 + yy
      prev = seg

    # check if path is closed
    if prev.x != @start.x || prev.y != @start.y
      throw new Error "yaya: Boundary: path not closed"

    # scale segments and change to uniform struct {type, p0..3: [x, y]}
    # rel: relative to boundary frame (immutable)
    l = p.length
    @rel = rel = new Array l
    prevP = [@start.x*k, -@start.y*k]
    for seg, i in p
      p0 = prevP
      prevP = p3 = [seg.x*k, -seg.y*k]
      rel[i] = r = {type: seg.type, p0, p3}
      if seg.type == 'C'
        r.p1 = [seg.x1*k, -seg.y1*k]
        r.p2 = [seg.x2*k, -seg.y2*k]
      else
        r.p1 = p0
        r.p2 = p3

    # abs: relative to world frame (updated each timestep)
    #   abs[i] = {type, x0, x1, x2, x3, y0, y1, y2, y3, aabb}
    # not populated until given boundary frame
    @abs = new Array l

    # dir: whether the path circles origin CCW (1) or CW (-1)
    # find this by taking cross product of starting point and starting tangent...
    # WARNING: THIS IS WRONG.
    ###
    @dir = do ->
      v0 = rel[0].p0
      switch rel[0].type
        when 'L' then vt = minus(rel[0].p3, v0)
        when 'C' then vt = minus(rel[0].p1, v0)
      Math.sign(cross(v0, vt))
    ###
    # temporary workaround: assume CCW.
    @dir = 1

    @ # done

  # assemble back to SVG path string
  toString: ->
    ret = "M #{@start.x} #{@start.y}\n"
    for {type, p0, p1, p2, p3} in @rel
      switch type
        when 'L'
          ret += "L #{p3[0]},#{p3[1]}\n"
        when 'C'
          ret += "C #{p1[0]},#{p1[1]} #{p2[0]},#{p2[1]} #{p3[0]},#{p3[1]}\n"
    ret

  # given coord of boundary frame (SE2) in world frame:
  #   update @abs
  #   calculate AABB(axis-aligned boundary box) for each segment and whole boundary
  update: (frame) ->
    # @rel => @abs
    for {type, p0, p1, p2, p3}, i in @rel
      [x0, y0] = frame.mulPoint p0
      [x3, y3] = frame.mulPoint p3
      if type == 'C'
        [x1, y1] = frame.mulPoint p1
        [x2, y2] = frame.mulPoint p2
      else
        x1 = x0; y1 = y0
        x2 = x3; y2 = y3
      @abs[i] = {type, x0, x1, x2, x3, y0, y1, y2, y3}

    # whole path AABB
    xMinP = yMinP = +Infinity
    xMaxP = yMaxP = -Infinity
    updP = ({xMin, xMax, yMin, yMax}) ->
      if xMin < xMinP then xMinP = xMin
      if xMax > xMaxP then xMaxP = xMax
      if yMin < yMinP then yMinP = yMin
      if yMax > yMaxP then yMaxP = yMax

    for seg in @abs
      switch seg.type
        when 'L'
          {x0, x3, y0, y3} = seg
          if x0 > x3 then [x0, x3] = [x3, x0]
          if y0 > y3 then [y0, y3] = [y3, y0]
          updP seg.aabb = {xMin: x0, xMax: x3, yMin: y0, yMax: y3}
        when 'C'
          updP seg.aabb = cbz.bound2 seg

    @aabb = {xMin: xMinP, xMax: xMaxP, yMin: yMinP, yMax: yMaxP}

  # find all *contacts* between two boundary curves (in world frame)
  # WARNING: huge function, lots of corner case, not guaranteed to work at all times
  # Dictionary for reading hugely-abbreviated variable names:
  #   l: LHS boundary
  #   r: RHS boundary
  #   u: first in an intersection pair
  #   v: second in an intersection pair
  #   s: segment
  #   p: point
  #   m: midpoint
  #   n: normal
  #   i: index of segment in boundary
  @getContacts = (bl, br, areaMerge) ->
    nl = bl.abs.length
    nr = br.abs.length

    # first find all intersections
    if !aabb.intersect(bl.aabb, br.aabb) then return []
    xList = []
    for sl, il in bl.abs
      for sr, ir in br.abs
        if !aabb.intersect(sl.aabb, sr.aabb) then continue
        for {x, y, tl, tr} in intersection[sl.type + sr.type](sl, sr)
          xList.push
            merged: false
            p: [x, y]
            l: {i: il, t: tl}
            r: {i: ir, t: tr}
            lNormal: null # normal pointing into interior of bl (exterior of br)
            depth: 0 # penetration depth (rough estimate)
            tag: {} # field for collision resolution algo to store extra information

    if xList.length == 0 then return []

    # signed polygon area helpers
    area3 = (a, b, c) ->
      cross(minus(b, a), minus(c, a))/2
    area4 = (a, b, c, d) ->
      ab = minus(b, a)
      ac = minus(c, a)
      ad = minus(d, a)
      (cross(ab, ac) + cross(ac, ad))/2

    # sort by position on L
    xList.sort (u, v) ->
      if (di = u.l.i - v.l.i) != 0 then return di
      u.l.t - v.l.t

    # iterate over all adjacent pairs of intersections
    iter = (cb) ->
      z = xList.length - 1
      for i in [0...z] by 1
        cb xList[i], xList[i+1]
      cb xList[z], xList[0]

    iter (u, v) ->
      if u.merged then return

      # some shorthand
      uli = u.l.i ; vli = v.l.i
      uri = u.r.i ; vri = v.r.i
      up = u.p  ; vp = v.p
      uvm = scale(plus(up, vp), 1/2) # midpoint of u & v
      uvd = minus(vp, up) # vector u->v
      uvn = normalize rot90 uvd # normal of u->v
      uls = bl.abs[uli] # bl segment where u is on
      urs = br.abs[uri] # br segment where u is on
      p0 = (seg) -> [seg.x0, seg.y0]
      p3 = (seg) -> [seg.x3, seg.y3]

      # estimate "midpoints" between u & v on bl/br
      ml = null
      mln = null # normal (pointing into interior of bl)
      mr = null
      mrn = null # normal (pointing into interior of br)

      if u == v
        # We're here because (xList.length == 1), so simply skip to the "no-merge" section below
        null
      else if norm(uvd) <= 1e-12
        # Now u, v are the same damn point!
        # This happens -- simply remove v
        v.merged = true
      else
        switch vli # if (u, v) are...
          when uli # on the same segment of bl
            switch uls.type
              when 'L'
                ml = uvm
                mln = uvn # correct direction, as u is before v
              when 'C'
                mlt = (u.l.t + v.l.t)/2 # midpoint => average bezier parameter
                ml = cbz.val2(uls, mlt)
                mln = normalize rot90 cbz.valD2(uls, mlt)
          when (uli + 1) % nl # on adjacent segments of bl (u before v)
            ml = p3(uls) # == p3(bl.abs[uli]) == p0(bl.abs[vli])

        # (almost-)symmetric code for br

        switch vri # if (u, v) are...
          when uri # on the same segment of br
            switch urs.type
              when 'L'
                mr = uvm
                # ATTENTION: (u, v) sorted by location on bl, not br.
                # Need to find out ordering of (u, v) on br in order to make
                # uvn point to interior of br
                mrn = if u.r.t < v.r.t then uvn else neg uvn
              when 'C'
                mrt = (u.r.t + v.r.t)/2 # midpoint => average bezier parameter
                mr = cbz.val2(urs, mrt)
                mrn = normalize rot90 cbz.valD2(urs, mrt)
          # again, here we need to detect correct "ordering"
          when (uri - 1) %% nr # on adjacent segments of br (v before u)
            mr = p0(urs) # == p0(br.abs[uri]) == p3(br.abs[vri])
          when (uri + 1) %  nr # on adjacent segments of br (u before v)
            mr = p3(urs) # == p3(br.abs[uri]) == p0(br.abs[vri])

      if ml? && mr?
        # both midpoint estimates are valid -- this is nice
        # use directed area to help measure penetration depth and tell if we can merge
        u.tag.msg = "good pre-merge"
        a = area4(up, ml, vp, mr)*bl.dir
        u.p = N.div(N.add(up, ml, vp, mr), 4)
        u.depth = abs(a*2/norm(uvd))
        if -1e-12 <= a <= areaMerge
          # merged: keep u (but use centroid of the contact polygon as merged contact), reject v
          u.p = N.div(N.add(up, ml, vp, mr), 4)
          v.merged = true
        # use different heruistics for estimating contact normal
        # NOTE: even when we don't merge becuase penetration area is too large,
        # since we have good enough geometry at u and v, estimation is probably
        # okay and we don't need to resort to below "singled" case
        if mln?
          if mrn?
            # same-same => average normals at two "midpoints"
            u.lNormal = avgNormal(mln, mrn)
          else
            # same-adj => use "same"-side normal
            u.lNormal = mln
        else
          if mrn?
            # adj-same => use "same"-side normal
            u.lNormal = neg mrn
          else
            # adj-adj => (a twilight zone) -- approx. w/ perpendicular bisector of uv
            u.lNormal = uvn

      else
        # "singled" intersection at u : twilight zone if it doesn't end up merged, because
        # we probably have very deep/wide penetration by now, which makes depth estimation
        # quite tricky...

        # we'll first try to "salvage" a clean normal
        if mln?
          u.tag.msg = "bad, scavange mln"
          u.lNormal = mln
          # project two secants on "dirty" side onto clean normal
          d0 = abs dot(minus(p0(urs), up), mln)
          d3 = abs dot(minus(p3(urs), up), mln)
          u.depth = min(d0, d3)
        else if mrn?
          u.tag.msg = "bad, scavange mrn"
          u.lNormal = neg mrn
          d0 = abs dot(minus(p0(uls), up), mrn)
          d3 = abs dot(minus(p3(uls), up), mrn)
          u.depth = min(d0, d3)
        else
          # THIS IS SPARTAAAAAA!!!!!
          # giving up all hope already -- just try to come up with a number!
          u.tag.msg = "sparta"
          switch uls.type
            when 'L'
              uln = normalize rot90 minus(p3(uls), p0(uls))
            when 'C'
              uln = normalize rot90 cbz.valD2(uls, u.l.t)
          switch urs.type
            when 'L'
              urn = normalize rot90 minus(p3(urs), p0(urs))
            when 'C'
              urn = normalize rot90 cbz.valD2(urs, u.r.t)
          u.lNormal = n = avgNormal(uln, urn)
          d0l = abs dot(minus(p0(uls), up), n)
          d0r = abs dot(minus(p0(urs), up), n)
          d3l = abs dot(minus(p3(uls), up), n)
          d3r = abs dot(minus(p3(urs), up), n)
          u.depth = min(d0l, d0r, d3l, d3r) # yeah, I know this is BS. "WHATEVER".
      return # (iter (u, v) -> ...)

    # exclude "marked as merged" entries in one final pass
    (x for x in xList when !x.merged)