{abs} = M = Math

# findRoots = require 'companion-roots' # supposed to be fed into refining algo
findRoots = require 'durand-kerner'

module.exports =
  findRoots: findRoots
  findRealRoots: (p) ->
    [re, im] = findRoots p
    t for t, i in re when abs(im[i]) < 1e-12