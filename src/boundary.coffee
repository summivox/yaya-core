{sin, cos, tan, abs, sqrt, atan2, min, max, PI} = M = Math
N = require 'numeric'
assert = require 'assert'
util = require 'util'
svgPath = require 'svg-path'

SE2 = require './se2'
aabb = require './aabb'
{cbz, intersection} = require './geom'

print = (x) -> console.log util.inspect x, color: true, depth: null

module.exports = class Boundary
  constructor: (pathStr) ->
    if this not instanceof Boundary then return new Boundary pathStr

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
      switch seg.type
        when 'Q'
          seg.type = 'C'
          xx = seg.x1*2/3
          yy = seg.y1*2/3
          seg.x1 = prev.x / 3 + xx
          seg.y1 = prev.y / 3 + yy
          seg.x2 = seg.x  / 3 + xx
          seg.y2 = seg.y  / 3 + yy
          break
      prev = seg

    # check if path is closed
    assert prev.x == @start.x && prev.y == @start.y

    #TODO: tangent checks

    @path = p
    @ # done

  toString: ->
    p = new svgPath.Path @path
    p.toString()

  # calculate AABB(axis-aligned boundary box) for each segment and whole boundary curve
  # in the world frame
  # frame: SE2 coords of the curve frame
  calcAABB: (frame) ->
    # whole path AABB
    xMinP = yMinP = +Infinity
    xMaxP = yMaxP = -Infinity
    upd = ({xMin, xMax, yMin, yMax}) ->
      if xMin < xMinP then xMinP = xMin
      if xMax > xMaxP then xMaxP = xMax
      if yMin < yMinP then yMinP = yMin
      if yMax > yMaxP then yMaxP = yMax

    prevTr = frame.mulPoint @start
    for seg in @path
      segTr = frame.mulPoint [seg.x, seg.y]
      switch seg.type
        when 'L'
          [x1, y1] = prevTr
          [x2, y2] = segTr
          if x1 > x2 then [x1, x2] = [x2, x1]
          if y1 > y2 then [y1, y2] = [y2, y1]
          upd seg.aabb = {xMin: x1, xMax: x2, yMin: y1, yMax: y2}
        when 'C'
          [x0, y0] = prevTr
          [x1, y1] = frame.mulPoint [seg.x1, seg.y1]
          [x2, y2] = frame.mulPoint [seg.x2, seg.y2]
          [x3, y3] = segTr
          [xMin, xMax] = cbz.bound x0, x1, x2, x3
          [yMin, yMax] = cbz.bound y0, y1, y2, y3
          upd seg.aabb = {xMin, xMax, yMin, yMax}
      prevTr = segTr

    @aabb = {xMin: xMinP, xMax: xMaxP, yMin: yMinP, yMax: yMaxP}

  # returns all intersections between two boundary curves
  # each intersection is identified by segment index and location
  @intersect = (b1, b2) ->
    ret = []
    if !aabb.intersect(b1.aabb, b2.aabb) then return ret
    s1p = b1.start
    for s1, s1i in b1.path
      s2p = b2.start
      for s2, s2i in b2.path
        if !aabb.intersect(s1.aabb, s2.aabb) then continue

        if s1.type == 'L' && s2.type == 'L'
          null #TODO
        else if s1.type == 'L' || s2.type == 'L'
          null #TODO
        else
          null # TODO

        s2p = s2
      s1p = s1

    ret



do test = ->
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
  a.calcAABB SE2(0, 0, 30*deg)
  b = a.aabb
  print [b.xMin, b.xMax, b.yMin, b.yMax]
  print a