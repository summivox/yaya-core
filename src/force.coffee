N = require 'numeric'
M = Math

SE2 = require './se2'

# 2D Force, natively represented as Plucker coordinates (force + moment at origin)
module.exports = class Force extends SE2

  constructor: (fx, fy, mz) ->
    if this not instanceof Force then return new Force fx, fy, mz
    super fx, fy, mz

  # represent the same force at given origin (moment component changed)
  offsetOrigin: (v) ->
    if v.x then {x, y} = v else [x, y] = v
    a = @th/(@x*@x+@y*@y)
    th = (@y*a - x)*@y + (@x*a + y)*@x
    new Force @x, @y, th

  ############
  # inbound conversions

  # (force, moment) [alias of native]
  @fromForceMoment = ({x: fx, y: fy}, mz) ->
    new Force fx, fy, mz

  # (force, point on line of force)
  @fromForcePoint = ({x: fx, y: fy}, {x: px, y: py}) ->
    new Force fx, fy, px*fy-py*fx

  ############
  # outbound conversions

  # convert to acceleration of a rigid body
  toAcc: ({m, jz}) -> new SE2 @x/m, @y/m, @th/jz