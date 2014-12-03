_ = require 'lodash'

M = Math
N = require 'numeric'

History = require './history'
IterMap = require './iter-map'
SE2 = require './se2'
Force = require './force'
Body = require './body'
ForceFuncMgr = require './force-func-mgr'
Boundary = require './boundary'

defaultOptions =
  k: 3 # size of history = 2^k
  timestep:
    min: 1e-6
    max: 1e-2
  spaceScale: 1 # (1m) in simulated world = (spaceScale) px on display
  collision:
    tol: 1e-2
    iter: 4

module.exports = class World
  constructor: (options = {}) ->
    @options = _.cloneDeep defaultOptions
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
    # returned force is directly acting on the body
    #TODO: better define this
    @fields = []

    # dummy solver
    @solver = -> throw Error 'World: set acc solver before stepping'

    @ # done

  # return: null if fail, body if successful
  addBody: (id, body, boundaryPathStr) ->
    if @bodies.has id then return null
    if boundaryPathStr
      body.boundary = new Boundary boundaryPathStr, @options.spaceScale
    body.init @options
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
    @tNow.modified = true
    body

  #TODO: {add, remove}{Force, Field}

  _clampTime: (dt) ->
    M.min(M.max(dt,
      @options.timestep.min), @options.timestep.max)

  # advance simulation in time
  # dt: suggested timestep to take
  # {min, max}:
  # observer: debug callbacks revealing internals:
  #   collision: (collList) -> ...
  # return: actually performed timestep
  #TODO: refactor min/max timestep to here -- better semantics
  step: (dt, observer = {}) ->
    dt = @solver(@tNow.t, @_clampTime(dt))


    ############
    # collision detection:
    #   only handle bodies with boundaries attached
    #   check each pair (unordered) once

    collBodies = []
    collList = []
    @bodies.forEach (body) ->
      if body.boundary?
        body.boundary.update body.frame.pos
        collBodies.push body
    l = collBodies.length
    for i in [0...l-1] by 1
      bi = collBodies[i]
      for j in [i+1...l] by 1
        bj = collBodies[j]
        if bi.drive && bj.drive then continue
        contacts = Boundary.getContacts(bi.boundary, bj.boundary, @options.collision.tol)
        if contacts.length > 0
          collList.push {a: bi, b: bj, contacts}
    observer.collision? collList


    ############
    # collision resolution

    # preprocess each contact
    for {a, b, contacts} in collList
      for {p, lNormal, tag} in contacts
        tag.imp = 0
        tag.n = n = Force.fromForcePoint(lNormal, p)
        tag.denom = 1/SE2.plus(n.toAcc(a), n.toAcc(b)).dot(n)

    for iter in [0...@options.collision.iter] by 1
      for {a, b, contacts} in collList
        for {p, lNormal, tag} in contacts
          impOld = tag.imp
          tag.imp += tag.n.dot(SE2.minus(b.frame.vel, a.frame.vel))*tag.denom
          if tag.imp < 1e-12 then tag.imp = 0
          impD = tag.imp - impOld
          impV = new Force tag.n.scale(impD)
          a.frame.vel.plusEq(impV.toAcc(a))
          b.frame.vel.minusEq(impV.toAcc(b))


    #TODO: discontinuity fix, etc.

    # save current state
    @tNow.t += dt
    @tNow.lastStep = dt
    @tNow.modified = false
    @tHistory.snapshot()
    @bodies.forEach (body) ->
      body.frameHistory.snapshot()

    dt

  # called by solvers: calculate acceleration of all bodies according
  # to their "temporary next step" pos & vel
  #TODO: "call before first step", "init"
  _getAcc: (t, dt) ->
    @bodies.forEach (body, id) =>
      acc = body.frame.acc = SE2(0, 0, 0)
      for field in @fields
        force = field(t, body, id)
        acc.plusEq force.toAcc body
    @forceFuncs.forEach (ffEntry) ->
      {bodyP, bodyN} = ffEntry
      forceP = ffEntry.f(t, dt) # need to preserve context
      if bodyP && bodyP != @ground
        # forceP: moment component already at bodyP
        bodyP.frame.acc.plusEq forceP.toAcc(bodyP)
      if bodyN && bodyN != @ground
        # forceN: -forceP with moment component offset to bodyN
        vPN = bodyN.frame.pos.minus bodyP.frame.pos
        forceN = new Force(forceP.neg()).offsetOrigin(vPN)
        bodyN.frame.acc.plusEq forceN.toAcc(bodyN)
