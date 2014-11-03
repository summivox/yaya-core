M = Math
N = require 'numeric'

History = require './history'

module.exports = class Body
  # m: mass (concentrated at origin)
  # jz: moment of inertia around origin
  # frame: {p, v, a} (SE(2) coordinates)
  #   p: position
  #   v: velocity
  #   a: acceleration
  # forceFuncs: ref entries of ForceFuncs associated with this body
  constructor: (@m, @jz, @frame) ->
    @forceFuncs = []

  # reason for independent init: propagate options from World
  init: (k) ->
    @frameHistory = new History @frame, k
