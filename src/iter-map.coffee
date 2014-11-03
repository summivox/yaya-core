# Transparent wrapper around ES6 Map for faster `forEach` iteration
# (actually `forEach` is not supported by node.js yet)
module.exports = class IterMap
  constructor: (arr) ->
    @_m = new Map
    @_l = []
    if arr?.length
      for [key, val] in arr
        @set key, val
    @ # done

  Object.defineProperty IterMap::, 'size', get: -> @_l.length

  clear: ->
    @_m.clear()
    @_l = []
    return

  set: (key, val) ->
    i = @_m.get key
    if i?
      @_l[i][1] = val
    else
      n = @_l.push [key, val]
      @_m.set key, n-1
    return this

  get: (key) ->
    i = @_m.get key
    if !i? then return
    @_l[i][1]

  has: (key) -> @_m.has key

  delete: (key) ->
    i = @_m.get key
    if !i? then return false
    j = @_l.length - 1
    @_swap i, j
    @_m.delete key
    @_l.pop()
    return true

  forEach: (cb, cbThis) ->
    if !cb?.call? then throw Error 'IterMap: forEach: invalid callback'
    for [key, val] in @_l
      cb.call cbThis, val, key, @
    return

  _swap: (i, j) ->
    [@_l[i], @_l[j]] = [a = @_l[j], b = @_l[i]]
    @_m.set a[0], i
    @_m.set b[0], j
    return