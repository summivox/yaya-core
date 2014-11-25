M = Math
N = require 'numeric'
_ = require 'lodash'

SE2 = require './se2'
History = require './history'
Boundary = require './boundary'

module.exports = class Body
  # m: mass (concentrated at origin)
  # jz: moment of inertia around origin
  # frame: {p, v, a} (SE(2) coordinates)
  #   p: position
  #   v: velocity
  #   a: acceleration
  # forceFuncs: ref entries of ForceFuncs associated with this body
  # boundary: simple closed curve acting as 
  constructor: (@m, @jz, frame = {}) ->
    if this not instanceof Body then return new Body m, jz, frame
    @forceFuncs = []
    @frame =
      pos: SE2(0, 0, 0)
      vel: SE2(0, 0, 0)
      acc: SE2(0, 0, 0)
    _.merge @frame, frame
    @boundary = null

  # reason for independent init: propagate options from World
  init: (options) ->
    @frameHistory = new History @frame, options.k