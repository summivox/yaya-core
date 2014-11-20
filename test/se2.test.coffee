{sin, cos, sqrt, PI, atan2, abs} = M = Math
N = require 'numeric'

SE2 = require '../src/se2'

deg = PI/180
sqrt2 = sqrt 2
sqrt5 = sqrt 5

module.exports =
  ctor: (test) ->
    s1 = SE2 2, 1, 45*deg
    test.equal s1.x, 2
    test.equal s1.y, 1
    test.equal s1.th, 45*deg

    s2 = SE2 s1
    test.deepEqual s1, s2, 'copy ctor'

    s3 = s1.clone()
    test.deepEqual s1, s3, 'clone'

    test.done()

  conversion: (test) ->
    s1 = SE2 2, 1, 45*deg
    test.deepEqual s1.toVec(), [2, 1], 'toVec'
    rot = s1.toRot() ; rot_ans = [[1/sqrt2, -1/sqrt2], [1/sqrt2, 1/sqrt2]]
    hom = s1.toHomogeneous() ; hom_ans = [[1/sqrt2, -1/sqrt2, 2], [1/sqrt2, 1/sqrt2, 1], [0, 0, 1]]
    matcmp = (a, b) ->
      N.all(N.leq(N.abs(N.sub(a, b)), 1e-12))
    test.ok matcmp(rot, rot_ans), 'toRot'
    test.ok matcmp(hom, hom_ans), 'toHomogeneous'

    test.done()

  addition: (test) ->
    s1 = SE2 2, 1, 45*deg
    s2 = SE2 -4, -2, 90*deg

    s3 = s1.plus s2
    test.deepEqual s3, SE2(-2, -1, 135*deg), 'plus'
    s4 = s1.minus s2
    test.deepEqual s4, SE2(6, 3, -45*deg), 'minus'
    s5 = s1.scale 3
    test.deepEqual s5, SE2(6, 3, 135*deg), 'scale'
    s6 = s1.neg()
    test.deepEqual s6, SE2(-2, -1, -45*deg), 'neg'
    s7 = SE2.plus(s1, s2, s3)
    test.deepEqual s7, SE2(-4, -2, 270*deg), 'plus-reduce'

    test.deepEqual s1, SE2(2, 1, 45*deg), 'immutable #1'
    test.deepEqual s2, SE2(-4, -2, 90*deg), 'immutable #2'

    test.done()

  multiplication: (test) ->
    s1 = SE2 2, 1, atan2(1, 2)
    s2 = SE2 0, -1, -90*deg
    vx = [1, 0]
    vy = [0, 1]

    # account for round-off errors
    eps0 = 1e-9
    vec_equal = (eps) -> (l, r) ->
      N.norm2(N.add(l, N.neg r)) < eps
#    SE2_equal = (eps) -> (l, r) ->
#      {x, y, th} = l.minus r # relying on addition test to pass
#      N.norm2([x, y]) < eps && abs(th) < eps

    vx0 = s1.mulVec vx
    vy0 = s1.mulVec vy
    test.ok vec_equal(eps0)(vx0, [2/sqrt5, 1/sqrt5]), 'mulVec [1, 0]'
    test.ok vec_equal(eps0)(vy0, [-1/sqrt5, 2/sqrt5]), 'mulVec [0, 1]'

    px0 = s1.mulPoint vx
    py0 = s1.mulPoint vy
    test.ok vec_equal(eps0)(px0, [2+2/sqrt5, 1+1/sqrt5]), 'mulPoint [1, 0]'
    test.ok vec_equal(eps0)(py0, [2-1/sqrt5, 1+2/sqrt5]), 'mulPoint [0, 1]'

    s3 = s1.mulSE2 s2; s3_ans = SE2(2+1/sqrt5, 1-2/sqrt5, atan2(1, 2)-90*deg)
    s4 = s2.mulSE2 s1; s4_ans = SE2(1, -3, atan2(1, 2)-90*deg)
    test.ok SE2.equal(s3, s3_ans, eps0), 'mulSE2 #1'
    test.ok SE2.equal(s4, s4_ans, eps0), 'mulSE2 #2'

    test.deepEqual s1, SE2(2, 1, atan2(1, 2)), 'immutable #1'
    test.deepEqual s2, SE2(0, -1, -90*deg), 'immutable #2'

    test.done()



