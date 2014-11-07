N = require 'numeric'
M = Math

SE2 = require './se2'

# 2D Force, natively represented as Plucker coordinates (force + moment at origin)
module.exports = class Force extends SE2

  constructor: ->
    if this not instanceof Force then return new Force arguments...
    super arguments...

  # represent moment component relative to another frame
  #   frame: SE(2) coordinate of frame
  inFrame: (frame) ->
    a = @th/(@x*@x+@y*@y)
    th = (@y*a - frame.x)*@y + (@x*a + frame.y)*@x
    # 20141104: DAMN THIS MISTAKE! We're still calculating in global frame so no rotation
    #[x, y] = frame.ldivVec([@x, @y])
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