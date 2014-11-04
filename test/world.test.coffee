{sin, cos, tan, atan2, abs, sqrt, PI} = M = Math
N = require 'numeric'
csv = require 'csv'
fs = require 'fs'

deg = PI/180
sqrt2 = sqrt 2
sqrt5 = sqrt 5

{World, Force, Body, SE2, Solver} = require '../index'

spring = (k, d0) -> (t) ->
  v = @bodyN.frame.pos.minus @bodyP.frame.pos
  d = N.norm2([v.x, v.y])
  d = M.max d, 1e3*N.epsilon # overlapping bodies have no direction
  Force.fromForcePoint v.scale(k*(1-d0/d)), @bodyP.frame.pos

uniformGravity = (g) -> (t, body, id) ->
  Force.fromForcePoint {x: 0, y: -g*body.m}, body.frame.pos


twoBodySpringWorld = (k = 1, d0 = 1) ->
  w = new World
  b1 = w.addBody 'b1', new Body(1, 1, pos: SE2(1, 1, 0))
  b2 = w.addBody 'b2', new Body(2, 1, pos: SE2(2, 3, 0))
  w.forceFuncs.add b1, b2, spring(k, d0)
  w

uniformGravityWorld = ->
  w = new World
  b1 = w.addBody 'b1', new Body(1, 1, pos: SE2(10, 1, 45*deg))
  b2 = w.addBody 'b2', new Body(5, 1, pos: SE2(-10, 5, -45*deg))
  w.fields.push uniformGravity(10)
  w

module.exports =
  getAcc:
    twoBodySpring: (test) ->
      w = twoBodySpringWorld()
      b1 = w.findBody('b1')
      b2 = w.findBody('b2')

      w._getAcc()

      x = 1-1/sqrt5
      test.ok SE2(x, x*2, 0).equal(b1.frame.acc), 'body #1'
      test.ok SE2(-x/2, -x, 0).equal(b2.frame.acc), 'body #2'

      console.log b1.frame.acc
      console.log b2.frame.acc

      test.done()

    uniformGravity: (test) ->
      w = uniformGravityWorld()
      b1 = w.findBody('b1')
      b2 = w.findBody('b2')

      w._getAcc()

      test.ok SE2(-10/sqrt2, -10/sqrt2, 0).equal(b1.frame.acc, 1e-12), 'body #1'
      test.ok SE2(10/sqrt2, -10/sqrt2, 0).equal(b2.frame.acc, 1e-12), 'body #2'

      test.done()
  outputOnly:
    verletFixed:
      twoBodySpring: (test) ->
        w = twoBodySpringWorld(1, 1)
        w.solver = Solver.verletFixed
        b1 = w.findBody('b1')
        b2 = w.findBody('b2')

        fOut = fs.createWriteStream './verletFixed.twoBodySpring.csv'
        csvOut = csv.stringify()
        csvOut.pipe fOut

        dt = 1e-3
        tTotal = 5
        for step in [1..tTotal/dt] by 1
          w.step dt
          csvOut.write [dt*step].concat(b1.frame.pos.toVec()).concat(b2.frame.pos.toVec())
        csvOut.end()

        test.ok abs(w.tNow.t - tTotal) <= 1e-12

        test.done()