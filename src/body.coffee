M = Math
N = require 'numeric'
_ = require 'lodash'

SE2 = require './se2'
History = require './history'
Boundary = require './boundary'

module.exports = class Body
  # m: mass (concentrated at origin)
  # jz: moment of inertia around origin
  # frame: {pos, vel, acc} (all SE2)
  # forceFuncs: ref entries of ForceFuncs associated with this body
  # boundary: simple closed curve acting as collision boundary
  # drive:
  #   null => not driven (free)
  #   {type, func}
  #     type: 'pos'/'vel'
  #     func: (t, dt) -> SE2
  constructor: (@m, @jz, frame = {}) ->
    if this not instanceof Body then return new Body m, jz, frame
    @forceFuncs = []
    @frame =
      pos: SE2(0, 0, 0)
      vel: SE2(0, 0, 0)
      acc: SE2(0, 0, 0)
    _.merge @frame, frame
    @boundary = null

    @drive = null

  # reason for independent init: propagate options from World
  init: (options) ->
    @frameHistory = new History @frame, options.k, (o) ->
      # custom: preserve SE2 class by using copy constructor
      # really I think this is a bug of lodash -- but anyway here we go
      _.cloneDeep o, (x) -> if x instanceof SE2 then new SE2 x else undefined
    @frameHistory.snapshot()