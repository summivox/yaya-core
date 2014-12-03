{sin, cos, sqrt, PI, atan2, abs} = M = Math
N = require 'numeric'

Force = require '../src/force'
SE2 = require '../src/se2'

deg = PI/180
sqrt2 = sqrt 2
sqrt5 = sqrt 5

module.exports =
  ctor: (test) ->
    f1 = new Force 1, 2, 3
    test.equal f1.x, 1
    test.equal f1.y, 2
    test.equal f1.th, 3

    f2 = new Force f1
    test.deepEqual f2, f1

    f2.x = -1
    test.equal f1.x, 1

    test.done()

  convert: (test) ->
    f1 = new Force 1, 2, 3
    test.deepEqual f1.toAcc({m: 1, jz: 3}), {x: 1, y: 2, th: 1}

    f2 = Force.fromForceMoment [1, 2], 3
    test.deepEqual f2, f1

    f3 = Force.fromForcePoint [1, 2], [1, -1]
    test.deepEqual f3, f1

    test.done()

  offsetOrigin: (test) ->
    f1 = Force.fromForcePoint [0, 2], [3, 0]
    frame1 = SE2(1, 2, 45*deg)
    f2 = f1.offsetOrigin frame1

    # account for round-off errors
#    SE2_equal = (eps) -> (l, r) ->
#      {x, y, th} = l.minus r # relying on addition test to pass
#      N.norm2([x, y]) < eps && abs(th) < eps

    test.ok SE2(0, 2, 4).equal(f2, 1e-12)

    test.done()
