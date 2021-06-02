public class _TicketStoreStorage<Ticket, Value> where Ticket: Comparable {
  public typealias Element = (Ticket, Value)
  
  @usableFromInline
  internal var _storage: UnsafeMutableBufferPointer<Element>
  
  @usableFromInline
  internal var _nextFreeIndex = 0
  
  @usableFromInline
  internal var _slotsInUse: _UnsafeBitset
  
  @usableFromInline
  internal var _slotsInUseStorage: UnsafeMutableBufferPointer<_UnsafeBitset.Word>
  
  @usableFromInline
  internal var _count: Int = 0
  
  @inlinable
  init(initialCapacity: Int = 1) {
    let capacity = initialCapacity > 0 ? initialCapacity : 1
    _storage = UnsafeMutableBufferPointer<Element>.allocate(capacity: capacity)
    _slotsInUseStorage = UnsafeMutableBufferPointer<_UnsafeBitset.Word>.allocate(capacity: _UnsafeBitset.wordCount(forCapacity: capacity))
    _slotsInUseStorage.initialize(repeating: .empty)
    _slotsInUse = _UnsafeBitset(words: _slotsInUseStorage, count: capacity)
  }
  
  @inlinable
  deinit {
    // TODO: There may be a faster way to do this ("chunking" the slots or something)
    for initializedIdx in _slotsInUse {
      _storage.baseAddress!.advanced(by: initializedIdx).deinitialize(count: 1)
    }
    _storage.deallocate()
    _slotsInUseStorage.deallocate()
  }
  
  @inlinable
  public var count: Int {
    _count
  }
  
  @inlinable
  public var isEmpty: Bool {
    _count <= 0
  }
  
  @inlinable
  public func append(_ element: Element) {
    if _nextFreeIndex >= _storage.count { // Need to resize before we can insert
      resize(newCapacity: _storage.count * 2) // TODO: Should this just be the *initialized* `count` * 2?
    }

    _storage.baseAddress!.advanced(by: _nextFreeIndex).initialize(to: element)
    _slotsInUse.insert(_nextFreeIndex)
    _nextFreeIndex += 1
    _count += 1
  }

  // If our storage utilization is below the compactingThresholdRatio *and* our count
  // of elements is *greater* than the minimum at which we don't worry about compacting at all,
  // we'll reduce our storage footprint.
  @inline(__always)
  public func remove(_ index: Int, compactingThresholdRatio: Double, minCountToCompact: Int = 1) {
    assert(_slotsInUse.contains(index))
    _storage.baseAddress!.advanced(by: index).deinitialize(count: 1)
    _slotsInUse.remove(index)
    _count -= 1
    
    // May not want this? It'll save you compactions in the case where you're appending & popping
    // a bunch at the end... and if we had to guess at the most frequently accessed element, it'd
    // probably be reasonable to pick either the most or the least recently inserted... but that's
    // still a pretty wild guess.
    if index == _nextFreeIndex - 1 {
      _nextFreeIndex -= 1
    }

    let percentUsed = Double(_count) / Double(_storage.count)
    let safeCountToCompact = minCountToCompact > 0 ? minCountToCompact : 1
    if percentUsed < compactingThresholdRatio && _count > safeCountToCompact {
      resize(newCapacity: _count)
    }
  }

  // Returns the internal storage index at which this ticket exists, or nil if it does not exist.
  // Performs a straight linear search if the size of the data structure is small enough,
  // otherwise does a binary search.
  public func search(for ticket: Ticket) -> Int? {
    let binarySearchElementsThreshold = 200
    return _storage.count < binarySearchElementsThreshold ?
      linearSearch(for: ticket) :
      binarySearch(for: ticket)
  }

  // Returns the "slot" index at which this ticket exists, or nil if the ticket does not exist.
  internal func linearSearch(for ticket: Ticket) -> Int? {
    for idx in 0..<_storage.count where _slotsInUse.contains(idx) {
      if ticketAtIndexUnsafe(idx) == ticket {
        return idx
      }
    }
    return nil
  }

  // Returns the "slot" index at which this ticket exists, or nil if the ticket does not exist.
  // This is undoubtably the worst implementation of binary search I've ever writen, but,
  // to paraphrase Jack Sparrow, it *does* work.
  internal func binarySearch(for ticket: Ticket) -> Int? {
    guard var l = firstSlotInUse() else { return nil }
    var n = _storage.count

    while n > 0 {
      let half = n / 2
      if let mid = firstSlotInUse(atOrAfter: l + half) {
        if ticketAtIndexUnsafe(mid) > ticket {
          n = half
        } else if ticketAtIndexUnsafe(mid) == ticket {
          return mid
        } else if let nextL = firstSlotInUse(atOrAfter: mid + 1) {
          l = nextL
          n -= half + 1
        } else {
          return nil
        }
      } else {
        n -= half
      }
    }

    return ticketAtIndexUnsafe(l) == ticket ? l : nil
  }

  internal func valueAtIndex(_ index: Int) -> Value? {
    _slotsInUse.contains(index) ? _storage[index].1 : nil
  }

  internal func set(_ value: Value, atIndex index: Int) {
    if _slotsInUse.contains(index) {
      _storage[index].1 = value
    }
  }
  
  @inlinable
  internal func resize(newCapacity: Int) {
    assert(newCapacity >= _count)
    let resized = UnsafeMutableBufferPointer<Element>.allocate(capacity: newCapacity)
    
    if _storage.count == count { // fast path: all slots initialized
      resized.baseAddress?.moveInitialize(from: _storage.baseAddress!, count: _storage.count)
    } else { // only move the indices that were initialized
      _nextFreeIndex = 0
      for initializedIdx in _slotsInUse {
        resized[_nextFreeIndex] = _storage[initializedIdx]
        _nextFreeIndex += 1
      }
      _storage.deallocate()
    }

    _storage = resized

    _slotsInUseStorage.deallocate()

    // Post resize, we are always densely compacted
    _slotsInUseStorage = UnsafeMutableBufferPointer<_UnsafeBitset.Word>.allocate(capacity: _UnsafeBitset.wordCount(forCapacity: newCapacity))
    _slotsInUseStorage.initialize(repeating: .empty)
    _slotsInUse = _UnsafeBitset(words: _slotsInUseStorage, count: newCapacity)
    _slotsInUse.insertAll(upTo: count)
  }

  @inline(__always)
  internal func firstSlotInUse(atOrAfter: Int = 0) -> Int? {
    var index = atOrAfter
    while index < _storage.count && !_slotsInUse.contains(index) {
      index += 1
    }
    
    return index < _storage.count ? index : nil
  }

  @inline(__always)
  internal func ticketAtIndexUnsafe(_ index: Int) -> Ticket {
    _storage[index].0
  }
}

// Dumb hack to enable the _TicketStoreStorage.Iterator to call search (ugh)
fileprivate func searchHack<Ticket, Value>(store: _TicketStoreStorage<Ticket, Value>, for ticket: Ticket) -> Int? {
  store.search(for: ticket)
}

extension _TicketStoreStorage: Sequence {
  @frozen
  public struct Iterator: IteratorProtocol {
    public typealias Element = _TicketStoreStorage.Element
    
    @usableFromInline
    internal let _base: _TicketStoreStorage
    
    @usableFromInline
    internal var _ticket: Ticket? // use a ticket, not a raw index, to support modifying while iterating

    @inline(__always)
    internal init(_base: _TicketStoreStorage) {
      self._base = _base
      if let firstIdx = _base.firstSlotInUse() {
        _ticket = _base._storage[firstIdx].0
      }
    }
    
    public mutating func next() -> Element? {
      if let t = _ticket,
         let idx = searchHack(store: _base, for: t) {
        if let nextPos = _base.firstSlotInUse(atOrAfter: idx + 1) {
          _ticket = _base._storage[nextPos].0
        } else {
          _ticket = nil
        }

        return _base._storage[idx]
      }
      return nil
    }
  }
  
  @inlinable
  @inline(__always)
  public var underestimatedCount: Int {
    _count
  }

  @inline(__always)
  public func makeIterator() -> Iterator {
    Iterator(_base: self)
  }
}

public struct TicketStore<Ticket, Value> where Ticket: Comparable {
  @usableFromInline internal var _storage: _TicketStoreStorage<Ticket, Value>
  @usableFromInline internal var _formNext: (Ticket) -> Ticket
  @usableFromInline internal var _next: Ticket
  
  // If fewer than this proportion of "slots" are filled after a removal, it
  // will trigger a compaction (clearing out empty space in the storage).
  // We *could* make this user-configurable (you could set it to 1 to compact
  // after every removal, or 0 to never compact), but a ratio of half the slots
  // filled is at the very least a good default.
  @usableFromInline
  internal let compactingThreshold = 0.5
  
  @inlinable
  public init(startingAt: Ticket, nextTicketGenerator: @escaping (Ticket) -> Ticket) {
    _next = startingAt
    _formNext = nextTicketGenerator
    _storage = _TicketStoreStorage()
  }
  
  // Inspecting a ticket store
  //------------------------------------------------------------------------------------
  public var isEmpty: Bool { _storage.isEmpty }
  public var count: Int { _storage._count } // we increment on insert, decrement on remove
  
  public func contains(_ ticket: Ticket) -> Bool {
    self[ticket] != nil
  }
  
  // Accessing elements
  //------------------------------------------------------------------------------------
  // Blasts through a straight linear search for a small number of elements,
  // and falls back to a binary search for a large number.
  // nil if we don't have this ticket at all
  public subscript(_ ticketIndex: Ticket) -> Value? {
    if let idx = _storage.search(for: ticketIndex) {
      return _storage.valueAtIndex(idx)
    }
    return nil
  }
  
  // Adding keys and values
  //------------------------------------------------------------------------------------
  public mutating func insert(_ newValue: Value) -> Ticket {
    let ticket = _next
    _storage.append((ticket, newValue))
    _next = _formNext(ticket)
    return ticket
  }
  
  // Returns the value that was replaced, or nil if the ticket was not found,
  // and therefore no change occurred
  @discardableResult
  public mutating func tryUpdate(_ value: Value, forTicket ticket: Ticket) -> Value? {
    if let idx = _storage.search(for: ticket),
       let previousValue = _storage.valueAtIndex(idx) {
      _storage.set(value, atIndex: idx)
      return previousValue
    }
    return nil
  }
  
  // Removing Tickets and Values
  //------------------------------------------------------------------------------------
  // Returns nil if we couldn't find this ticket, otherwise the value removed
  @discardableResult
  public mutating func removeValue(forTicket ticket: Ticket) -> Value? {
    if let idx = _storage.search(for: ticket),
       let previousValue = _storage.valueAtIndex(idx) {
      _storage.remove(idx, compactingThresholdRatio: compactingThreshold)
      return previousValue
    }
    return nil
  }
  
  public mutating func removeAll() {
    _storage = _TicketStoreStorage()
  }
}



extension TicketStore where Ticket: Numeric {
  @inlinable
  public init(startingAt: Ticket) {
    self.init(startingAt: startingAt, nextTicketGenerator: { $0 + 1 })
  }
}
extension TicketStore where Ticket: BinaryInteger {
  @inlinable
  public init() {
    self.init(startingAt: 0)
  }
}

#warning("Implement encode")
extension TicketStore: Encodable where Ticket: Encodable, Value: Encodable {
  @inlinable
  public func encode(to encoder: Encoder) throws { }
}

#warning("Implement decode")
extension TicketStore: Decodable where Ticket: Decodable, Value: Decodable {
  @inlinable
  public init(from decoder: Decoder) throws {
    self.init(startingAt: try Ticket(from: decoder), nextTicketGenerator: { $0 })
  }
}

#warning("Implement debug description")
extension TicketStore: CustomDebugStringConvertible {
  public var debugDescription: String {
    ""
  }
}

// TODO: CustomReflectable?? (I don't know enough about Swift's reflection to say anything about this)

extension TicketStore: CustomStringConvertible {
  #warning("Implement description")
  public var description: String {
    "TODO: Implement"
  }
}

extension TicketStore: Equatable where Ticket: Equatable, Value: Equatable {
  @inlinable
  public static func ==(left: Self, right: Self) -> Bool {
    // There's a philosophical question here of whether two stores whose *next* (or worse, next-generator)
    // are not identical should be considered equal. I think in practice, though, it makes the most
    // sense to consider them equal if their current elements are equal.
    left._storage.elementsEqual(right._storage, by: { $0 == $1 })
  }
}

extension TicketStore: Hashable where Ticket: Hashable, Value: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {
    for element in _storage {
      hasher.combine(element.0)
      hasher.combine(element.1)
    }
  }
}

extension TicketStore: Sequence {
  public typealias Element = (key: Ticket, value: Value)
  
  @frozen
  public struct Iterator: IteratorProtocol {
    @usableFromInline
    internal var _impl: _TicketStoreStorage<Ticket, Value>.Iterator
    
    @inlinable
    @inline(__always)
    internal init(_base: TicketStore) {
      _impl = _base._storage.makeIterator()
    }
    
    @inlinable
    public mutating func next() -> Element? {
      _impl.next()
    }
  }
  
  @inlinable
  @inline(__always)
  public var underestimatedCount: Int {
    _storage._count
  }
  
  @inlinable
  @inline(__always)
  public func makeIterator() -> Iterator {
    Iterator(_base: self)
  }
}

