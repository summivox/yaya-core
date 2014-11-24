{sin, cos, tan, abs, sqrt, atan2, min, max, PI} = M = Math
N = require 'numeric'
assert = require 'assert'
util = require 'util'
svgPath = require 'svg-path'
_ = require 'lodash'

SE2 = require './se2'
{aabb, cbz, intersection} = require './geom'

print = (x) -> console.log util.inspect x, color: true, depth: null

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
    assert prev.x == @start.x && prev.y == @start.y

    # scale segments and change to uniform struct {type, p0..3: [x, y]}
    # rel: relative to boundary frame (immutable)
    @rel = rel = new Array p.length
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
    @abs = null

    #TODO: tangent checks

    @ # done

  # assemble back to SVG path string
  toString: ->
    ret = "M #{@start.x} #{@start.y}\n"
    for {type, p0, p1, p2, p3} in seg
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
    for {type, p0, p1, p2, p3}, i in @rel
      [x0, y0] = frame.mulPoint p0
      [x3, y3] = frame.mulPoint p3
      if type == 'C'
        [x1, y1] = frame.mulPoint p1
        [x2, y2] = frame.mulPoint p2
      else
        [x1, y1] = p0
        [x2, y2] = p3
      @abs[i] = {type, x0, x1, x2, x3, y0, y1, y2, y3}

    # whole path AABB
    xMinP = yMinP = +Infinity
    xMaxP = yMaxP = -Infinity
    upd = ({xMin, xMax, yMin, yMax}) ->
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
          upd seg.aabb = {xMin: x0, xMax: x3, yMin: y0, yMax: y3}
        when 'C'
          upd seg.aabb = cbz.bound2 seg

    @aabb = {xMin: xMinP, xMax: xMaxP, yMin: yMinP, yMax: yMaxP}

  # returns all intersections between two boundary curves (in world frame)
  # each intersection is identified by segment index and location
  @intersect = (bl, br) ->
    ret = []
    if !aabb.intersect(bl.aabb, br.aabb) then return ret
    for sl, sli in bl.path
      for sr, sri in br.path
        if !aabb.intersect(sl.aabb, s2.aabb) then continue
        xs = intersect[sl.type + sr.type](sl, sr)
        for {x, y, tl, tr} in xs
          ret.push {x, y, sli, tl, sri, tr}
    ret


test = ->
  deg = PI/180
  a = new Boundary """
        m 300 100
        h -100 v 100
        q -100 0 -100 100
        t 100 100
        c 50 0 50 100 150 100
        s 0 -100 150 -100
        q 100 -100 0 -200
        z
  """
  console.log a.toString()
  print a
  a.calcAABB SE2(0, 0, 30*deg)
  b = a.aabb
  print [b.xMin, b.xMax, b.yMin, b.yMax]
  print a
# do test