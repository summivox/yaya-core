_ = require 'lodash'

Body = require './body'

module.exports = class ForceFuncMgr
  constructor: ->
    @_a = []

  # f: (t, dt) -> {x, y, th}
  #   t: simulation time
  #   dt: timestep
  #   returned force acts on and has moment component relative to @bodyP ("positive")
  #   its reaction force is exerted (by World) onto @bodyN ("negative")
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