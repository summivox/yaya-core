_ = require 'lodash'

# Circular buffer for keeping recent 2^k snapshots of enclosed object
# with a timestamp attached for each snapshot
module.exports = class History
  # @o: the object
  # @k: determines the size of the buffer
  constructor: (@now, @k) ->
    if !now?
      throw Error 'History: ctor: object is empty'
    if !k || k != ~~k || k < 0
      throw Error 'History: ctor: `k` should be non-negative integer'
    @n = n = 1<<k

    @_mask = n - 1
    @_h = new Array n # history (transformed and deep-copied)
    @_t = (0 for i in [0...n]) #
    @_i = 0 # index of the latest snapshot

  # take a snapshot of the underlying object, optionally passing through
  # given transformation `(o) -> x`
  snapshot: (time, transform) ->
    snap = _.clone transform @now
    i = @_i = (@_i + 1|0) & @_mask
    @_h[i] = snap
    @_t[i] = time

  # past(0) -> most recent {o: object, t: timestamp}
  # past(-1) -> second most recent
  # ...
  past: (index) ->
    i = (index | @n) & @_mask
    debugger
    o: @_h[i]
    t: @_t[i]