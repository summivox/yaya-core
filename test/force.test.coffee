Force = require '../src/force'

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
    test.deepEqual f1.toAcceleration({m: 1, jz: 3}), {x: 1, y: 2, th: 1}

    f2 = Force.fromForceMoment {x: 1, y: 2}, 3
    test.deepEqual f2, f1

    f3 = Force.fromForcePoint {x: 1, y: 2}, {x: 1, y: -1}
    test.deepEqual f3, f1

    test.done()