#
#
#            Nim's Runtime Library
#        (c) Copyright 2019 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# An ``include`` file for Robin Hood table implementation.

include hashcommon

template initImpl(result: typed, size: int) =
  assert isPowerOfTwo(size)
  result.counter = 0
  newSeq(result.data, size)

template rawInsertImpl() {.dirty.} =
  t.data[h].hcode = hc
  t.data[h].dist = dist
  t.data[h].key = key
  t.data[h].val = val

proc rawInsert[X, A, B](t: var X, data: var KeyValuePairSeq[A, B],
                        key: A, val: B, hc: Hash, h: Hash, dist: int) =
  rawInsertImpl()

template maybeRehashPutImpl(enlarge) {.dirty.} =
  if t.dataLen == 0:
    initImpl(t, defaultInitialSize)
  if mustRehash(t.dataLen, t.counter):
    enlarge(t)
    index = rawGet(t, key, hc)
    assert(index < -1, "my logic is wrong") # XXX remove when battle-tested
  index = -2 - index                  # important to transform for mgetOrPutImpl
  rawInsert(t, t.data, key, val, hc, index, dist)
  inc(t.counter)

template putImpl2(enlarge) {.dirty.} =
  var # needed for eventual swapping
    key = key
    val = val
  if t.dataLen == 0:
    initImpl(t, defaultInitialSize)
  var hc: Hash
  genHashImpl(key, hc)
  var
    h: Hash = hc and maxHash(t)   # start with real hash value
    dist = 0
    # index = -1
  while index < 0: # we pass the existing index to this template
    index = rawGetKnownHC(t, key, hc, h, dist)
    if index >= 0: # existing key
      t.data[index].val = val
      t.data[index].dist = dist
    elif index == -1: # key exists with smaller dist, need to swap them
      swap hc, t.data[h].hcode
      swap key, t.data[h].key
      swap val, t.data[h].val
      swap dist, t.data[h].dist
    else:
      maybeRehashPutImpl(enlarge)
      break

template putImpl(enlarge) {.dirty.} =
  var index = -1
  putImpl2(enlarge)

template hasKeyOrPutImpl(enlarge) {.dirty.} =
  if t.dataLen == 0:
    initImpl(t, defaultInitialSize)
  var hc: Hash
  var index = rawGet(t, key, hc)
  if index >= 0:
    result = true
  else:
    result = false
    putImpl2(enlarge) # this way we also do swapping if needed

template mgetOrPutImpl(enlarge) {.dirty.} =
  if t.dataLen == 0:
    initImpl(t, defaultInitialSize)
  var hc: Hash
  var index = rawGet(t, key, hc)
  if index < 0:
    # not present: insert (flipping index)
    putImpl2(enlarge)
  # either way return modifiable val
  result = t.data[index].val

template getOrDefaultImpl(t, key): untyped =
  # mixin rawGet
  var hc: Hash
  var index = rawGet(t, key, hc)
  if index >= 0: result = t.data[index].val

template getOrDefaultImpl(t, key, default: untyped): untyped =
  # mixin rawGet
  var hc: Hash
  var index = rawGet(t, key, hc)
  result = if index >= 0: t.data[index].val else: default

template delImplIdx(t, h) =
  if h >= 0:
    dec t.counter
    t.data[h].hcode = 0 # mark current as empty
    t.data[h].key = default(type(t.data[h].key))
    t.data[h].val = default(type(t.data[h].val))
    t.data[h].dist = 0
    # move all the following non-empty elements with dist >=1 to the left
    var j = nextTry(h, maxHash(t))
    while t.data[j].hcode != 0 and t.data[j].dist > 0:
      swap t.data[h], t.data[j]
      dec t.data[h].dist
      h = j # prepare for the next step: (h = j, j = j+1)
      j = nextTry(j, maxHash(t))

template delImpl() {.dirty.} =
  var hc: Hash
  var i = rawGet(t, key, hc)
  delImplIdx(t, i)

template clearImpl() {.dirty.} =
  for i in 0 ..< t.dataLen:
    when compiles(t.data[i].hcode): # CountTable records don't contain a hcode
      t.data[i].hcode = 0
    t.data[i].key = default(type(t.data[i].key))
    t.data[i].val = default(type(t.data[i].val))
    t.data[i].dist = 0
  t.counter = 0

template dollarImpl(): untyped {.dirty.} =
  if t.len == 0:
    result = "{:}"
  else:
    result = "{"
    for key, val in pairs(t):
      if result.len > 1: result.add(", ")
      result.addQuoted(key)
      result.add(": ")
      result.addQuoted(val)
    result.add("}")

template equalsImpl(s, t: typed): typed =
  if s.counter == t.counter:
    # different insertion orders mean different 'data' seqs, so we have
    # to use the slow route here:
    for key, val in s:
      if not t.hasKey(key): return false
      if t.getOrDefault(key) != val: return false
    return true










# ------- Count Table stuff, not ported yet

template insertImpl() = # for CountTable
  if t.dataLen == 0: initImpl(t, defaultInitialSize)
  if mustRehash(len(t.data), t.counter): enlarge(t)
  ctRawInsert(t, t.data, key, val)
  inc(t.counter)


