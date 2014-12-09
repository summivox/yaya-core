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
    iters: 4
    cor: 0.1
    posFix: 0.618

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
    dt = @_clampTime(dt)
    dt = @solver(@tNow.t, dt)

    {tol, iters, cor, posFix} = @options.collision

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
        contacts = Boundary.getContacts(bi.boundary, bj.boundary, tol)
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
        tag.k = (1+cor)/SE2.plus(n.toAcc(a), n.toAcc(b)).dot(n)

    #imps = []
    for iter in [1..iters] by 1
      for {a, b, contacts} in collList
        va = a.frame.vel
        vb = b.frame.vel
        for {p, lNormal, depth, tag} in contacts
          impOld = tag.imp
          tag.imp += (tag.n.dot(vb.minus(va)) + (Math.random()*0.5+0.5)*posFix*depth/dt)*tag.k
          if tag.imp < 1e-12 then tag.imp = 0
          if tag.imp > 20 then tag.imp = 20 #TODO: THIS IS A HACK!
          if isNaN tag.imp then tag.imp = 0
          #imps.push tag.imp
          impD = tag.imp - impOld
          impV = new Force tag.n.scale(impD)
          va.plusEq (impV.toAcc(a)) unless a.drive?
          vb.minusEq(impV.toAcc(b)) unless b.drive?

    #DEBUG: 你妈炸了
    ###
    if imps.length
      avg = N.sum(imps)/imps.length
      max = M.max(imps...)
      min = M.min(imps...)
      console.log "avg: #{avg.toFixed(8)}, max: #{max.toFixed(8)}, min: #{min.toFixed(8)}"
      if max > 20
        console.log @tNow.t
        console.log dt
        debugger
    ###

    # wrap angular position
    @bodies.forEach (body) ->
      PI = M.PI
      PPI = 2*M.PI
      if body.frame.th > +PPI then body.frame.th -= PI
      if body.frame.th < -PPI then body.frame.th += PI

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

  #DEBUG: list all bodies
  _list: ->
    @bodies.forEach (body, id) ->
      {x, y, th} = body.frame.pos
      console.log "{id: #{id}, pos: [#{x.toFixed(6)}, #{y.toFixed(6)}, #{th.toFixed(6)}]}"