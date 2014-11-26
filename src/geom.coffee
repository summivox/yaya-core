{sin, cos, tan, abs, sqrt, atan2, min, max, PI} = M = Math
N = require 'numeric'
{findRoots, findRealRoots} = require './poly-roots'

# axis-aligned bounding box helpers
# aabb: {xMin, xMax, yMin, yMax} (in world frame)
module.exports.aabb = aabb =
  intersect: (a, b) ->
    if a.xMax < b.xMin || b.xMax < a.xMin then return false
    if a.yMax < b.yMin || b.yMax < a.yMin then return false
    return true

# cubic bezier helpers (1D)
module.exports.cbz = cbz =
  # evaluate
  valT: (t) ->
    s = 1 - t
    ss = s*s
    sss = s*ss
    tt = t*t
    ttt = t*tt
    (p0, p1, p2, p3) -> sss*p0 + 3*ss*t*p1 + 3*s*tt*p2 + ttt*p3
  val: (p0, p1, p2, p3, t) -> cbz.valT(t)(p0, p1, p2, p3)
  val2: (c, t) ->
    f = cbz.valT(t)
    [f(c.x0, c.x1, c.x2, c.x3), f(c.y0, c.y1, c.y2, c.y3)]

  # split the curve at t
  # returns: [[a0, a1, a2, a3], [b0, b1, b2, b3]]
  splitT: (t) ->
    s = 1 - t
    ss = s*s
    sss = s*ss
    tt = t*t
    ttt = t*tt
    st2 = s*t*2
    sst3 = ss*t*3
    stt3 = s*tt*3
    (p0, p1, p2, p3) ->
      pt = sss*p0 + sst3*p1 + stt3*p2 + ttt*p3
      [
        [
          p0
          s*p0 + t*p1
          ss*p0 + st2*p1 + tt*p2
          pt
        ]
        [
          pt
          ss*p1 + st2*p2 + tt*p3
          s*p2 + t*p3
          p3
        ]
      ]
  split: (p0, p1, p2, p3, t) -> cbz.splitT(t)(p0, p1, p2, p3)
  split2: (c, t) ->
    f = cbz.splitT(t)
    a = {}
    b = {}
    [[a.x0, a.x1, a.x2, a.x3], [b.x0, b.x1, b.x2, b.x3]] = f(c.x0, c.x1, c.x2, c.x3)
    [[a.y0, a.y1, a.y2, a.y3], [b.y0, b.y1, b.y2, b.y3]] = f(c.y0, c.y1, c.y2, c.y3)
    [a, b]

  # polynomial coefficients, order 0 to 3
  poly: (p0, p1, p2, p3) ->
    [
      p0
      3*(-p0 + p1)
      3*(p0 - 2*p1 + p2)
      -p0 + 3*p1 - 3*p2 + p3
    ]

  # find roots of derivative
  dRoots: (p0, p1, p2, p3) ->
    findRealRoots [
      3*(-p0+p1)
      6*(p0-2*p1+p2)
      3*(-p0+3*p1-3*p2+p3)
    ]

  # bounding interval
  bound: (p0, p1, p2, p3) ->
    ps = [p0, p3]
    [t1, t2] = @dRoots p0, p1, p2, p3
    if 0 <= t1 <= 1 then ps.push cbz.val p0, p1, p2, p3, t1
    if 0 <= t2 <= 1 then ps.push cbz.val p0, p1, p2, p3, t2
    [min(ps...), max(ps...)]
  bound2: (c) ->
    {x0, x1, x2, x3, y0, y1, y2, y3} = c
    [xMin, xMax] = cbz.bound x0, x1, x2, x3
    [yMin, yMax] = cbz.bound y0, y1, y2, y3
    {xMin, xMax, yMin, yMax}


# intersection helpers (2D)
# return: [{x, y, tl, tr}] (point + curve params)
# input:
#   L: {x0, x3, y0, y3}
#   C: {x0..3, y0..3}
module.exports.intersection = intersection =
  eps: 1e-12
  depth_cc: 20

  LL: (l, r) ->
    # http://www.topcoder.com/tc?module=Static&d1=tutorials&d2=geometry2#line_line_intersection
    al = l.y3 - l.y0
    bl = l.x0 - l.x3
    cl = al*l.x0 + bl*l.y0
    ar = r.y3 - r.y0
    br = r.x0 - r.x3
    cr = ar*r.x0 + br*r.y0
    det = al*br - ar*bl
    if abs(det) <= @eps then return [] # ignore parallel cases
    x = (br*cl - bl*cr)/det
    y = (al*cr - ar*cl)/det
    if abs(al) < abs(bl) then tl = (l.x0 - x)/bl else tl = (y - l.y0)/al
    if !(0 <= tl <= 1) then return []
    if abs(ar) < abs(br) then tr = (r.x0 - x)/br else tr = (y - r.y0)/ar
    if !(0 <= tr <= 1) then return []
    [{x, y, tl, tr}]

  CL: (l, r) ->
    # derived from: http://www.particleincell.com/blog/2013/cubic-line-intersection/
    # basic idea: plug spline [x(t), y(t)] into line ax+by=c to get cubic poly p(t)
    polyX = cbz.poly(l.x0, l.x1, l.x2, l.x3)
    polyY = cbz.poly(l.y0, l.y1, l.y2, l.y3)
    ar = r.y3 - r.y0
    br = r.x0 - r.x3
    cr = ar*r.x0 + br*r.y0
    poly = N.add(N.mul(polyX, ar), N.mul(polyY, br))
    poly[0] -= cr
    roots = findRealRoots poly
    for tl in roots
      if !(0 <= tl <= 1) then continue
      x = cbz.val(l.x0, l.x1, l.x2, l.x3, tl)
      y = cbz.val(l.y0, l.y1, l.y2, l.y3, tl)
      if abs(ar) < abs(br) then tr = (r.x0 - x)/br else tr = (y - r.y0)/ar
      if !(0 <= tr <= 1) then continue
      {x, y, tl, tr}

  LC: (l, r) ->
    {x, y, tl, tr} for {x, y, tl: tr, tr: tl} in intersection.CL(r, l)

  CC: (L, R) ->
    ret = []

    # nn = 0 #DEBUG: timing

    # recursive bisection
    f = (l, lt, r, rt, n) ->
      # ++nn #DEBUG: timing

      # bounding box check
      bl = cbz.bound2 l
      br = cbz.bound2 r
      if !aabb.intersect(bl, br) then return

      ltm = (lt[0] + lt[1]) / 2
      rtm = (rt[0] + rt[1]) / 2

      # deep enough => found intersection
      if n == 0
        [x, y] = cbz.val2(l, ltm)
        ret.push {x, y, tl: ltm, tr: rtm}
        return

      # split the curve
      [l1, l2] = cbz.split2(l, 0.5)
      [r1, r2] = cbz.split2(r, 0.5)
      lt1 = [lt[0], ltm]
      lt2 = [ltm, lt[1]]
      rt1 = [rt[0], rtm]
      rt2 = [rtm, rt[1]]

      # test each pair
      f(l1, lt1, r1, rt1, n-1)
      f(l1, lt1, r2, rt2, n-1)
      f(l2, lt2, r1, rt1, n-1)
      f(l2, lt2, r2, rt2, n-1)

    # initial: test whole curve pair
    n0 = intersection.depth_cc
    f(L, [0, 1], R, [0, 1], n0)

    #DEBUG: timing
    # console.log nn

    # merge "duplicate" intersections
    ret.sort (a, b) -> a.tl - b.tl
    last = ret[0]
    retM = [last]
    e0 = 4/(1<<n0) # interval range tolerance
    for x in ret
      if -e0 <= (x.tl - last.tl) <= e0 then continue
      retM.push last = x
    retM

test = ->
  c1 =
    x0: -2.87147, y0: 2.1893
    x1: 3.10783, y1: 2.25972
    x2: -0.085317, y2: -2.31284
    x3: 3.56043, y3: -2.86662
  console.dir cbz.split2 c1, 0.3
  l =
    x0: -2, y0: 3
    x3: 3, y3: -2
  # console.dir intersection.CL c1, l
  c2 =
    x0: -1.3067334292909472, y0: 3.8629415448559428
    x1: 0.791902640219103, y1: 3.376208314133372
    x2: 0.6644856900883802, y2: -3.2024261729045396
    x3: 1.704852219895173, y3: 1.0996416534919113
  console.dir intersection.CC c1, c2
  # console.dir intersection.CC cbz.split2(c1, 0.5)[0], cbz.split2(c2, 0.5)[0]

# do test