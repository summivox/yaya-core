_ = require 'lodash'
util = require 'util'

# Circular buffer for keeping recent 2^k snapshots of enclosed object
# with a timestamp attached for each snapshot
module.exports = class History
  # @now: the object
  # @k: determines the size of the buffer
  constructor: (@now, @k, @transform) ->
    if !now?
      throw Error 'History: ctor: object is empty'
    if !k || k != ~~k || k < 0
      throw Error 'History: ctor: `k` should be non-negative integer'
    @transform ||= (o) -> o

    @n = n = 1<<k
    @_mask = n - 1
    @_h = new Array n # history (transformed and deep-copied)
    @_t = (0 for i in [0...n]) # timestamps
    @_i = @_mask # index of the latest snapshot

  # take a snapshot of the underlying object
  snapshot: (time) ->
    snap = _.cloneDeep @transform @now
    i = @_i = (@_i + 1|0) & @_mask
    @_h[i] = snap
    @_t[i] = time

  # past(0) -> most recent {o: object, t: timestamp}
  # past(-1) -> second most recent
  # ...
  past: (index) ->
    i = (index + @_i + @n) & @_mask
    o: @_h[i]
    t: @_t[i]

do test = ->
  o = v: [1]
  h = new History o, 2
  t = ({v}) -> {v, t: true}
  o.v[0] = 1; h.snapshot 100, t
  o.v[0] = 2; h.snapshot 200, t
  o.v[0] = 3; h.snapshot 300, t
  o.v[0] = 4; h.snapshot 400, t
  o.v[0] = 5; h.snapshot 500, t
  o.v[0] = 6; h.snapshot 600, t
  console.log util.inspect h, colors: true, depth: null
  console.log util.inspect h.past(i) for i in [0..-3]
