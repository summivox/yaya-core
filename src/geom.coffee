{sin, cos, tan, abs, sqrt, atan2, min, max, PI} = M = Math
N = require 'numeric'
{findRoots, findRealRoots} = require './poly-roots'

# cubic bezier helpers (1D)
module.exports.cbz = cbz =
  # evaluate
  eval: (p0, p1, p2, p3, t) ->
    tt = t*t
    ttt = t*tt
    u = 1 - t
    uu = u*u
    uuu = u*uu
    uuu*p0 + 3*uu*t*p1 + 3*u*tt*p2 + ttt*p3

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
    if 0 < t1 < 1 then ps.push @eval p0, p1, p2, p3, t1
    if 0 < t2 < 1 then ps.push @eval p0, p1, p2, p3, t2
    [min.apply(M, ps)
     max.apply(M, ps)]


# intersection helpers (2D)
# return: [{x, y, tl, tr}] (incl. curve param at intersection)
# input:
#   line: {x1, y1, x2, y2}
#   cbz: {x0..3, y0..3}
module.exports.intersection = intersection =
  eps: 1e-12

  line_line: (l, r) ->
    # http://www.topcoder.com/tc?module=Static&d1=tutorials&d2=geometry2#line_line_intersection
    al = l.y2 - l.y1
    bl = l.x1 - l.x2
    cl = al*l.x1 + bl*l.y1
    ar = r.y2 - r.y1
    br = r.x1 - r.x2
    cr = ar*r.x1 + br*r.y1
    det = al*br - ar*bl
    if abs(det) <= @eps then return []
    x = (br*cl - bl*cr)/det
    y = (al*cr - ar*cl)/det
    if abs(al) < abs(bl) then tl = (x - l.x1)/bl else tl = (y - l.y1)/al
    if !(0 <= tl <= 1) then return []
    if abs(ar) < abs(br) then tr = (x - r.x1)/br else tr = (y - r.y1)/ar
    if !(0 <= tr <= 1) then return []
    [{x, y, tl, tr}]

  cbz_line: (l, r) ->
    # derived from: http://www.particleincell.com/blog/2013/cubic-line-intersection/
    # basic idea: plug spline [x(t), y(t)] into line ax+by=c to get cubic poly p(t)
    polyX = cbz.poly(l.x0, l.x1, l.x2, l.x3)
    polyY = cbz.poly(l.y0, l.y1, l.y2, l.y3)
    ar = r.y2 - r.y1
    br = r.x1 - r.x2
    cr = ar*r.x1 + br*r.y1
    poly = N.add(N.mul(polyX, ar), N.mul(polyY, br))
    poly[0] -= cr
    roots = findRealRoots poly
    for tl in roots
      if !(0 <= tl <= 1) then continue
      x = cbz.eval(l.x0, l.x1, l.x2, l.x3, tl)
      y = cbz.eval(l.y0, l.y1, l.y2, l.y3, tl)
      if abs(ar) < abs(br) then tr = (x - r.x1)/b2 else tr = (y - r.y1)/ar
      if !(0 <= tr <= 1) then continue
      {x, y, tl, tr}


  line_cbz: (l, r) ->
    {x, y, tl, tr} for {x, y, tl: tr, tr: tl} in @cbz_line(r, l)

do test = ->
  l =
    x0: -2.87147, y0: 2.1893
    x1: 3.10783, y1: 2.25972
    x2: -0.085317, y2: -2.31284
    x3: 3.56043, y3: -2.86662
  r =
    x1: -2, y1: 3
    x2: 3, y2: -2
  ans = intersection.cbz_line l, r
  console.dir ans