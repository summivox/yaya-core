IterMap = require '../src/iter-map'

module.exports =
  simpleTest: (test) ->
    m = new IterMap
    m.set i, i*100 for i in [1..3]
    test.ok m.has i for i in [1..3]
    test.equal m.get(i), i*100 for i in [1..3]
    test.strictEqual m.get(4), undefined
    m.forEach (v, k, o) -> test.equal v, k*100
    test.equal m.size, 3

    #  console.log m._l
    #  console.log m._m.get i for i in [1..3]

    m.delete 1
    test.ok !(m.has 1)
    test.ok m.has i for i in [2..3]
    test.equal m.size, 2

    #  console.log m._l
    #  console.log m._m.get i for i in [2..3]

    m.set i, i*-100 for i in [2..4]
    test.ok m.has i for i in [2..4]
    test.ok !m.has(1)
    test.equal m.get(i), i*-100 for i in [2..4]
    test.strictEqual m.get(1), undefined
    test.equal m.size, 3

    test.done()