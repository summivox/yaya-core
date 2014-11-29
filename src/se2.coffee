{sin, cos, abs} = M = Math
N = require 'numeric'

# SE(2) can be seen as:
#   wrench/twist => addition
#   homogeneous transformation => multiplication
module.exports = class SE2
  # trivial and copy (with new-guard and default zeroing)
  constructor: (@x, @y, @th) ->
    if this not instanceof SE2 then return new SE2 x, y, th
    if typeof x != 'number'
      {x: @x, y: @y, th: @th} = x
    @x ?= 0; @y ?= 0; @th ?= 0
    @ # done

  clone: -> new SE2 @x, @y, @th

  ############
  # outbound conversion

  # origin point
  toVec: -> [@x, @y]

  # 2x2 rotation matrix
  toRot: ->
    c = cos @th ; s = sin @th
    [[c, -s], [s, c]]

  # 3x3 homogeneous transformation matrix
  toHomogeneous: ->
    c = cos @th
    s = sin @th
    [[c, -s, @x], [s, c, @y], [0, 0, 1]]


  ############
  # addition

  plus: ({x, y, th}) ->
    new SE2 @x+x, @y+y, @th+th
  minus: ({x, y, th}) ->
    new SE2 @x-x, @y-y, @th-th
  scale: (k) ->
    new SE2 @x*k, @y*k, @th*k
  neg: ->
    new SE2 -@x, -@y, -@th

  ############
  # multiplication

  # H^{-1}
  inv: ->
    c = cos @th; s = sin @th
    x = - c*x - s*y
    y = + s*x - c*y
    new SE2 x, y, -@th

  # H*(x, y, 0)^T
  mulVec: (v) ->
    if v.length then [x, y] = v
    else {x, y} = v
    c = cos @th; s = sin @th
    [+ c*x - s*y
     + s*x + c*y]

  # H*(x, y, 1)^T
  mulPoint: (p) ->
    [x, y] = @mulVec p
    [x + @x
     y + @y]

  # H^{-1}*(x, y, 0)^T
  ldivVec: (v) -> @neg().mulVec(v) # same result as @inv but faster

  # H^{-1}*(x, y, 1)^T
  ldivPoint: (p) -> @inv().mulPoint(p)

  # H_1 * H_2
  mulSE2: ({x, y, th}) ->
    [rx, ry] = @mulPoint {x, y}
    new SE2 rx, ry, th+@th

  ############
  # comparison

#  equal: ({x, y, th}) -> @x == x && @y == y && @th == th
  equal: (r, eps = 1e-12) ->
    {x, y, th} = @minus r
    N.norm2([x, y]) <= eps && abs(th) <= eps

  ############
  # addition/assign

  addEq: ({x, y, th}) ->
    @x += x; @y += y; @th += th; @
  minusEq: ({x, y, th}) ->
    @x -= x; @y -= y; @th -= th; @
  scaleEq: (k) ->
    @x *= k; @y *= k; @th *= k; @
  negEq: ->
    @x = -@x; @y = -@y; @th = -@th; @

  #NOTE: mul/assign intentionally not provided to avoid confusion

  ############
  # function-style operators

  @plus = (l, rs...) -> l = l.plus r for r in rs ; l
  @minus = (l, r) -> l.minus r
  @scale = (l, r) -> if l.x? then l.scale r else r.scale l
  @neg = (s) -> s.neg()
  @inv = (s) -> s.inv()
  @mulVec = (s, v) -> s.mulVec v
  @mulPoint = (s, p) -> s.mulPoint p
  @mulSE2 = (l, rs...) -> l = l.mulSE2 r for r in rs ; l
  @equal = (l, r, eps) -> l.equal r, eps