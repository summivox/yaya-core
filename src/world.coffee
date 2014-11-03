_ = require 'lodash'

M = Math
N = require 'numeric'

History = require './history'
IterMap = require './iter-map'
Force = require './force'
Body = require './body'
ForceFuncMgr = require './force-func-mgr'

defaultOptions =
  k: 3 # size of history = 2^k
  timestep:
    min: 1e-8
    max: 1e-4

module.exports = class World
  constructor: (@options) ->
    _.merge options, defaultOptions
    @_o = options

    # simulation time:
    #   t: timestamp of current state
    #   discontinuity: "truthy" if a discontinuity happened during previous timestep
    #   lastStep: timestep taken from last state to current
    # history is kept in sync with all bodies
    @tNow = {t: 0, discontinuity: true, lastStep: 0}
    @tHistory = new History @tNow, options.k
    @tHistory.snapshot()

    # set of bodies
    @bodies = new IterMap

    # special body: "ground" (leave room for refactoring)
    @ground = null

    # force function manager
    @forceFuncs = new ForceFuncMgr

    # solver0: bootstrapping solver used after discontinuity
    @solver = @solver0 = -> throw Error 'World: set a solver before stepping'

    @ # done

  # return: null if fail, body if successful
  addBody: (id, body) ->
    if @bodies.has id then return null
    body.init @options.k
    @bodies.set id, body
    @tNow.discontinuity = true
    return body

  findBody: (id) -> @bodies.get id

  # return: null if fail, body if successful
  removeBody: (id) ->
    body = @bodies.get id
    if !body? then return null
    @bodies.delete id
    for ffEntry in body.forceFuncs
      @forceFuncs.remove ffEntry, body
    body

  _clampTime = (dt) ->
    M.min(M.max(dt,
      @options.timestep.min), @options.timestep.max)

  # advance simulation in time
  # dt: suggested timestep to take
  # return: actually performed timestep
  step: (dt) ->
    dt = @_clampTime dt
    dt = if @tNow.discontinuity then @solver0 dt else @solver dt

    #TODO: post-solver correction, discontinuity fix, etc.
    # for now just switch discontinuity off after stepping
    tNow.discontinuity = false

    tNow.t += dt
    tNow.lastStep = dt
    tHistory.snapshot()
    bodies.forEach (body) ->
      body.frameHistory.snapshot()

    dt

  # called by solvers: calculate acceleration of all bodies according
  # to their "temporary next step" pos & vel
  _getAcc: (dt) ->
    t = tNow.t + dt
    @bodies.forEach (body) -> body.frame.a = {x: 0, y: 0, th: 0}
    @forceFuncs.forEach (ffEntry) ->
      {bodyP, bodyN, f} = ffEntry
      {x, y, th} = forceP = f t
      forceN = {x: -x, y: -y, th: -th}
      #TODO: implement "+="
      bodyP.frame.a += forceP.toAcceleration bodyP
      bodyN.frame.a += forceN.toAcceleration bodyN
