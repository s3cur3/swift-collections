public struct TicketStore<Ticket, Value> where Ticket: Comparable {
    @usableFromInline internal var _storage: UnsafeMutableBuffer<(Ticket, Value)>
	@usableFromInline internal var _slotsInUse: _UnsafeBitset
	@usableFromInline internal var _formNext: (Ticket) -> Ticket
	@usableFromInline internal var _next: Ticket = Ticket()

	// If fewer than this proportion of "slots" are filled after a removal, it
	// will trigger a compaction (clearing out empty space in the storage).
	// We *could* make this user-configurable (you could set it to 1 to compact
	// after every removal, or 0 to never compact), but a ratio of half the slots
	// filled is at the very least a good default.
	@usableFromInline
	internal let compactingThreshold: 0.5

    @inlinable
	public init(startingAt: Ticket, nextTicketGenerator: @escaping (Ticket) -> Ticket = { $0 + 1 }) { }

	// Inspecting a ticket store
	//------------------------------------------------------------------------------------
	var isEmpty: Bool { }
	var capacity: Int { }
	var count: Int { } // we increment on insert, decrement on remove

	func contains(_: Ticket) -> Bool { }

	// Accessing elements
	//------------------------------------------------------------------------------------
	// Probably best to blast through a straight linear search for a small number of elements,
	// and fall back to a binary search for a large number. (Dunno if the conditional "sometimes
	// O(n), sometimes O(log n)" complexity is a problem, though?)
	// nil if we don't have this ticket at all
	subscript(_ index: Ticket) -> Value? { get }

	// Note: We can only provide these in constant time if we're compacting with each removal...
	//       Otherwise it's O(n) in the worst case. Do we need to make these function calls?
	var first: (Ticket, Value)? { }
	var last: (Ticket, Value)? { }

	// Adding keys and values
	//------------------------------------------------------------------------------------
	func insert(_ newValue: Value) -> Ticket { }

	// Returns value that was replaced, or nil if a new key-value pair was added.
	@discardableResult
	mutating func updateValue(_ value: Value, forKey: Ticket) -> Value? { }

	// Merge strikes me as being of limited use, but it's easy enough to implement.
	mutating func merge(_ other: TicketStore<Ticket, Value>, uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows { }
	mutating func merge<S>(_ other: S, uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows where S : Sequence, S.Element == (Ticket, Value) { }

	func merging(_ other: TicketStore<Ticket, Value>, uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows -> TicketStore<Ticket, Value> { }
	func merging<S>(_ other: S, uniquingKeysWith combine: (Value, Value) throws -> Value) rethrows -> TicketStore<Ticket, Value> where S : Sequence, S.Element == (Ticket, Value) { }

	mutating func reserveCapacity(_ minimumCapacity: Int) { }

	// Removing Tickets and Values
	//------------------------------------------------------------------------------------
	func filterTickets(_ isIncluded: Ticket) throws -> Bool) rethrows -> TicketStore<Ticket, Value> { }
	func filterValues(_ isIncluded: Value) throws -> Bool) rethrows -> TicketStore<Ticket, Value> { }

	@discardableResult
	mutating func removeValue(forTicket ticket: Ticket) -> Value? { }

	mutating func removeAll(keepingCapacity: Bool = false) { }

	mutating func popFirst() -> (Ticket, Value)? { }


	// Iterating over Tickets and Values
	//------------------------------------------------------------------------------------
	func forEach(_ body: ((ticket: Ticket, value: Value)) throws -> Void) rethrows { }
	func forEachValue(_ body: (value: Value) throws -> Void) rethrows { }

	// Finding elements
	//------------------------------------------------------------------------------------
	func allSatisfy(_ predicate: ((ticket: Ticket, value: Value)) throws -> Bool) rethrows -> Bool { }
	func first(where predicate: ((ticket: Ticket, value: Value)) throws -> Bool) rethrows -> (Ticket, Value)? { }
	func firstTicket(where predicate: (Value) throws -> Bool) rethrows -> Ticket? { }

	var description: String { }
}


extension TicketStore: Encodable where Ticket: Encodable, Value: Encodable {
  @inlinable
  public func encode(to encoder: Encoder) throws { }
}

extension TicketStore: Decodable where Ticket: Decodable, Value: Decodable {
  @inlinable
  public init(from decoder: Decoder) throws { }
}

extension TicketStore: CustomDebugStringConvertible {
	public var debugDescription: String { }
}

// TODO: CustomReflectable?? (I don't know enough about Swift's reflection to say anything about this)

extension TicketStore: CustomStringConvertible {
	public var description: String { }
}

extension TicketStore: Equatable where Ticket: Equatable, Value: Equatable {
  @inlinable
  public static func ==(left: Self, right: Self) -> Bool { }
}

extension TicketStore: Hashable where Value: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) { }
}

extension TicketStore: Sequence {
  public typealias Element = (key: Ticket, value: Value)

  @frozen
  public struct Iterator: IteratorProtocol {
	@usableFromInline
	internal let _base: TicketStore

	@usableFromInline
	internal var _position: Int

	@inlinable
	@inline(__always)
	internal init(_base: TicketStore) { }

	@inlinable
	public mutating func next() -> Element? { }
  }

  @inlinable
  @inline(__always)
  public var underestimatedCount: Int { }

  @inlinable
  @inline(__always)
  public func makeIterator() -> Iterator { }
}
