N = require 'numeric'
M = Math

SE2 = require './se2'

# 2D Force, natively represented as Plucker coordinates (force + moment at origin)
module.exports = class Force extends SE2

  constructor: -> super arguments...

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
  toAcceleration: ({m, jz}) -> new SE2 @x/m, @y/m, @th/jz