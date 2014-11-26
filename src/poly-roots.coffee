{abs} = M = Math

# findRoots = require 'companion-roots' # supposed to be fed into refining algo
findRoots = require 'durand-kerner'

module.exports = polyRoots =
  findRoots: (p) ->
    # remove denormal high-order terms
    l = p.length
    for i in [l-1..0] by -1
      if abs(p[i]) <= 1e-12
        p.pop()
    findRoots p
  findRealRoots: (p) ->
    [re, im] = polyRoots.findRoots p
    if !re? then return []
    t for t, i in re when abs(im[i]) < 1e-12