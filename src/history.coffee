_ = require 'lodash'
util = require 'util'

# Circular buffer for keeping recent 2^k snapshots of enclosed object
module.exports = class History
  # @now: the object
  # @k: determines the size of the buffer
  constructor: (@now, @k, @transform = _.cloneDeep) ->
    if !now?
      throw Error 'History: ctor: object is empty'
    if !k || k != ~~k || k < 0
      throw Error 'History: ctor: `k` should be non-negative integer'

    @n = 1<<k
    @_mask = @n - 1
    @clear()

    @ # done

  clear: ->
    @_h = new Array @n # history (transformed and deep-copied)
    @_i = @_mask # index of the latest snapshot
    return

  # take a snapshot of the underlying object
  snapshot: ->
    snap = @transform @now
    i = @_i = (@_i + 1|0) & @_mask
    @_h[i] = snap

  # past(0) -> most recent
  # past(-1) -> second most recent
  # ...
  past: (index) ->
    i = (index + @_i + @n) & @_mask
    @_h[i]