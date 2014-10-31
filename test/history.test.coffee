History = require '../src/history'

module.exports =
  simpleTest: (test) ->
    o = v: [1]
    t = ({v}) -> {v, t: true}
    h = new History o, 2, t

    o.v[0] = 1; h.snapshot()
    o.v[0] = 2; h.snapshot()
    o.v[0] = 3; h.snapshot()
    o.v[0] = 4; h.snapshot()

    test.equal o.v[0], 4
    test.ok !o.t?
    for i in [0..-3]
      p = h.past(i)
      test.strictEqual p.t, true
      test.equal p.v[0], 4+i

    o.v[0] = 5; h.snapshot()
    o.v[0] = 6; h.snapshot()

    test.equal o.v[0], 6
    test.ok !o.t?
    for i in [0..-3]
      p = h.past(i)
      test.strictEqual p.t, true
      test.equal p.v[0], 6+i

    o.v[0] = 7; h.snapshot()
    o.v[0] = 8; h.snapshot()

    test.equal o.v[0], 8
    test.ok !o.t?
    for i in [0..-3]
      p = h.past(i)
      test.strictEqual p.t, true
      test.equal p.v[0], 8+i

    test.done()