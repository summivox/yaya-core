{sin, cos, sqrt, PI, atan2, abs} = M = Math
N = require 'numeric'
assert = require 'assert'

SE2 = require './se2'

module.exports =
  # Velocity Verlet, fixed timestep
  # http://en.wikipedia.org/wiki/Verlet_integration#Velocity_Verlet
  # NOTE:
  #   If acc(t+dt) depends on vel(t+dt), only a predicted value is available initially,
  #   in which case the vel->acc integration becomes Euler. One ad-hoc iteration step
  #   is added as an attempt to save some accuracy.
  verletFixed: (t, dt) ->
    hdt = dt/2
    hdt2 = dt*dt/2
    @bodies.forEach (body) =>
      {pos: pos0, vel: vel0, acc: acc0} = body.frameHistory.past(0)
      if !body.drive?
        body.frame.pos = SE2.plus(pos0, vel0.scale(dt), acc0.scale(hdt2))
        body.frame.vel = SE2.plus(vel0, acc0.scale(dt)) # the Euler step (prediction only)
        @_getAcc(t, dt) ; acc1 = body.frame.acc
        body.frame.vel = SE2.plus(vel0, acc0.scale(hdt), acc1.scale(hdt))
        #@_getAcc(t, dt) ; acc1 = body.frame.acc
        #body.frame.vel = SE2.plus(vel0, acc0.scale(hdt), acc1.scale(hdt))
      else switch body.drive.type
        when 'pos'
          pos1 = body.drive.func t, dt
          posD = SE2.minus(pos1, pos0)
          body.frame.pos = pos1
          body.frame.vel = SE2.scale(posD, 1/dt) #TODO: better differentiation
        #TODO: when 'vel'
    return dt

  # Beeman, predictor-corrector, fixed timestep
  # http://en.wikipedia.org/wiki/Beeman%27s_algorithm#Predictor-Corrector_Modifications
  beemanFixed: (t, dt) ->
    dt2 = dt*dt
    p1a0 = dt2*2/3 ; p1a_1 = -dt2/6
    v1a0 = dt*3/2  ; v1a_1 = -dt/2
    v2a1 = dt*5/12 ; v2a0  = dt*2/3 ; v2a_1 = -dt/12
    @bodies.forEach (body) =>
      {pos: pos0, vel: vel0, acc: acc0} = body.frameHistory.past(0)
      {pos: pos_1, vel: vel_1, acc: acc_1} = body.frameHistory.past(-1)

      # predictor: calculate {pos, vel}(t+dt)
      body.frame.pos = SE2.plus(pos0, vel0.scale(dt), acc0.scale(p1a0), acc_1.scale(p1a_1))
      body.frame.vel = SE2.plus(vel0, acc0.scale(v1a0), acc_1.scale(v1a_1))

      # prepare acc(t+dt)
      @_getAcc(dt)
      acc1 = body.frame.acc

      # correct vel(t+dt)
      body.frame.vel = SE2.plus(vel0, acc1.scale(v2a1), acc0.scale(v2a0), acc_1.scale(v2a_1))

    return dt