_ = require 'lodash'

M = Math
N = require 'numeric'

History = require './history'
IterMap = require './iter-map'
SE2 = require './se2'
Force = require './force'
Body = require './body'
ForceFuncMgr = require './force-func-mgr'

defaultOptions =
  k: 3 # size of history = 2^k
  timestep:
    min: 1e-6
    max: 1e-2

module.exports = class World
  constructor: (options = {}) ->
    @options = _.clone defaultOptions
    _.merge @options, options

    # simulation time struct:
    #   t: timestamp of current state
    #   lastStep: time spent from last state to current
    #   modified: if objects in the world has changed after this iteration
    #   tag: for solver to store arbitrary state
    # history is kept in sync with all bodies
    @tNow = {t: 0, lastStep: 0, modified: true, tag: null}
    @tHistory = new History @tNow, @options.k
    @tHistory.snapshot()

    # set of bodies
    @bodies = new IterMap

    # special body: "ground" (leave room for refactoring)
    @ground = null

    # force function manager
    @forceFuncs = new ForceFuncMgr

    # list of fields `(t, body, id) -> Force`
    @fields = []

    # dummy solver
    @solver = -> throw Error 'World: set acc solver before stepping'

    @ # done

  # return: null if fail, body if successful
  addBody: (id, body) ->
    if @bodies.has id then return null
    body.init @options.k
    @bodies.set id, body
    @tNow.modified = true
    return body

  findBody: (id) -> @bodies.get id

  # return: null if fail, body if successful
  removeBody: (id) ->
    body = @bodies.get id
    if !body? then return null
    @bodies.delete id
    for ffEntry in body.forceFuncs
      @forceFuncs.remove ffEntry, body
    @tnow.modified = true
    body

  #TODO: {add, remove}{Force, Field}

  _clampTime: (dt) ->
    M.min(M.max(dt,
      @options.timestep.min), @options.timestep.max)

  # advance simulation in time
  # dt: suggested timestep to take
  # return: actually performed timestep
  step: (dt) ->
    dt = @solver @_clampTime dt

    #TODO: post-solver correction, discontinuity fix, etc.
    # for now just switch discontinuity off after stepping
    @tNow.discontinuity = false

    # save current state
    @tNow.t += dt
    @tNow.lastStep = dt
    @tHistory.snapshot()
    @bodies.forEach (body) ->
      body.frameHistory.snapshot()

    dt

  # called by solvers: calculate acceleration of all bodies according
  # to their "temporary next step" pos & vel
  _getAcc: (dt) ->

    # Force on Body => body Acc
    fb2a = (force, body) -> force.inFrame(body.frame.pos).toAcc(body)

    t = @tNow.t + dt
    @bodies.forEach (body, id) =>
      acc = body.frame.acc = SE2(0, 0, 0)
      for field in @fields
        force = field(t, body, id)
        acc.addEq fb2a(force, body)
    @forceFuncs.forEach (ffEntry) ->
      {bodyP, bodyN} = ffEntry
      forceP = ffEntry.f(t) # need to preserve context
      if bodyP != @ground
        bodyP.frame.acc.addEq fb2a(forceP, bodyP)
      if bodyN != @ground
        forceN = new Force forceP.neg()
        bodyN.frame.acc.addEq fb2a(forceN, bodyN)
