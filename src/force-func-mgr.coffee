_ = require 'lodash'

Body = require './body'

module.exports = class ForceFuncMgr
  constructor: ->
    @_a = []

  # f: (t) -> {x, y, th}
  #   @bodyP: force acting on this body is the same as returned ("positive")
  #   @bodyN: force acting on this body is negative of returned ("negative")
  #   t: simulation time
  add: (bodyP, bodyN, f) ->
    ffEntry = {_idx: @_a.length, bodyP, bodyN, f}
    @_a.push ffEntry
    if bodyP instanceof Body then bodyP.forceFuncs.push ffEntry
    if bodyN instanceof Body then bodyN.forceFuncs.push ffEntry

  # ffEntry: reference to force func struct
  # body: the body to be removed if this is being removed due to that
  # returns: null if fail, ffEntry if successful
  remove: (ffEntry, body) ->
    i = ffEntry._idx
    if !i? then return null # double-removing
    j = @_a.length - 1
    @_swap i, j
    @_a.pop()
    ffEntry._idx = null

    {bodyP, bodyN} = ffEntry
    if bodyP instanceof Body && bodyP != body
      _.pull bodyP.forceFuncs, ffEntry
    if bodyN instanceof Body && bodyN != body
      _.pull bodyN.forceFuncs, ffEntry

    return ffEntry

  forEach: (f) -> @_a.forEach f

  _swap: (i, j) ->
    [@_a[i], @_a[j]] = [p = @_a[j], q = @_a[i]]
    p._idx = i
    q._idx = j