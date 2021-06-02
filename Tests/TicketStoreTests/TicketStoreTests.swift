//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import XCTest
import CollectionsTestSupport
@_spi(Testing) import TicketStore

final class TicketStoreStorageTests: CollectionTestCase {
  func test_insertion() {
    var store = TicketStore<Int, Double>()
    expectTrue(store.isEmpty)
    expectFalse(store.contains(0))

    expectEqual(store.insert(2.71), 0)
    expectEqual(store.insert(3.14), 1)
    expectEqual(store.insert(6.28), 2)

    expectEqual(store.count, 3)

    expectTrue(store.contains(0))
    expectTrue(store.contains(1))
    expectTrue(store.contains(2))

    expectEqual(store[0], 2.71)
    expectEqual(store[1], 3.14)
    expectEqual(store[2], 6.28)
  }

  func test_lookup() {
    // In reality, you probably wouldn't want a floating point value as your ticket type,
    // but we only *require* it to be comparable, so it's legal.
    var store = TicketStore<Double, String>(startingAt: 100.0)
    expectEqual(store.insert("a"), 100.0)
    expectEqual(store.insert("b"), 101.0)
    expectEqual(store.insert("c"), 102.0)
    expectEqual(store.insert("d"), 103.0)
    expectEqual(store.insert("e"), 104.0)

    expectEqual(store[100.0], "a")
    expectEqual(store[101.0], "b")
    expectEqual(store[102.0], "c")
    expectEqual(store[103.0], "d")
    expectEqual(store[104.0], "e")

    expectNil(store[0])
    expectNil(store[1])
    expectNil(store[100.001])
    expectNil(store[105.0])
  }

  func test_singleRemoval() {
    var store = TicketStore<Int, Double>(startingAt: 0, nextTicketGenerator: { $0 + 1 })
    expectEqual(store.insert(2.71), 0)
    expectEqual(store.insert(3.14), 1)
    expectEqual(store.insert(6.28), 2)

    expectEqual(store.removeValue(forTicket: 1), 3.14)
    expectTrue(store.contains(0))
    expectFalse(store.contains(1))
    expectTrue(store.contains(2))
    expectEqual(store.count, 2)

    expectEqual(store.removeValue(forTicket: 0), 2.71)
    expectFalse(store.contains(0))
    expectFalse(store.contains(1))
    expectTrue(store.contains(2))
    expectEqual(store.count, 1)

    expectEqual(store.removeValue(forTicket: 2), 6.28)
    expectFalse(store.contains(0))
    expectFalse(store.contains(1))
    expectFalse(store.contains(2))
    expectEqual(store.count, 0)

    expectNil(store.removeValue(forTicket: 3))
  }

  func test_mixedInsertAndRemove() {
    var store = TicketStore<UInt8, String>()
    expectEqual(store.insert("a"), 0)
    expectEqual(store.insert("b"), 1)
    expectEqual(store.insert("c"), 2)
    expectEqual(store.insert("d"), 3)
    expectEqual(store.insert("e"), 4)
    expectEqual(store.insert("f"), 5)
    expectEqual(store.count, 6)

    // Remove all odd tickets
    expectEqual(store.removeValue(forTicket: 3), "d")
    expectEqual(store.removeValue(forTicket: 1), "b")
    expectEqual(store.removeValue(forTicket: 5), "f")

    expectEqual(store.count, 3)

    expectEqual(store.insert("g"), 6)
    expectEqual(store.insert("h"), 7)
    expectEqual(store.insert("i"), 8)
    expectEqual(store.count, 6)

    expectEqual(store.removeValue(forTicket: 7), "h")

    expectEqual(store.count, 5)

    for (ticket, _) in store {
      store.removeValue(forTicket: ticket)
    }
    expectTrue(store.isEmpty)

    expectEqual(store.insert("j"), 9)
    expectEqual(store.count, 1)
  }


  func test_removeAll() {
    var store = TicketStore<Int, Double>(startingAt: 0, nextTicketGenerator: { $0 + 1 })
    expectEqual(store.insert(2.71), 0)
    expectEqual(store.insert(3.14), 1)
    expectEqual(store.insert(6.28), 2)

    store.removeAll()
    expectEqual(store.count, 0)
    expectTrue(store.isEmpty)

    expectFalse(store.contains(0))
    expectFalse(store.contains(1))
    expectFalse(store.contains(2))
  }

  func test_update() {
    let startDate = Date()
    var store = TicketStore<Date, (String, String)>(startingAt: startDate, nextTicketGenerator: { $0 + 1 })
    expectEqual(store.insert(("zero", "0")), startDate)
    expectEqual(store.insert(("one", "1")), startDate + 1)
    expectEqual(store.insert(("two", "2")), startDate + 2)
    let initialValueFor3 = ("three", "3")
    expectEqual(store.insert(initialValueFor3), startDate + 3)

    let updatedValueFor3 = ("3", "three")
    let receivedPrevValue = store.tryUpdate(updatedValueFor3, forTicket: startDate + 3)
    expectEqual(receivedPrevValue!.0, initialValueFor3.0)
    expectEqual(receivedPrevValue!.1, initialValueFor3.1)
    expectEqual(store[startDate + 3]!.0, updatedValueFor3.0)
    expectEqual(store[startDate + 3]!.1, updatedValueFor3.1)

    expectNil(store.tryUpdate(("won't", "work"), forTicket: startDate - 1))
    expectNil(store.tryUpdate(("won't", "work"), forTicket: startDate + 4))
  }

  func test_equalEmpty() {
    expectEqual(TicketStore<Int, Date>(), TicketStore<Int, Date>())

    // This describes the current behavior, but (per the comment on ==(),
    // it's potentially surprising.
    expectEqual(TicketStore<Int, Date>(startingAt: 0), TicketStore<Int, Date>(startingAt: 1))

    let startDate = Date()
    expectEqual(TicketStore<Date, [Int: String]>(startingAt: startDate, nextTicketGenerator: { $0 + 1 }),
                TicketStore<Date, [Int: String]>(startingAt: startDate, nextTicketGenerator: { $0 + 1 }))
  }

  func test_equalWithData() {
    let startDate = Date()
    var store1 = TicketStore<Date, [String]>(startingAt: startDate, nextTicketGenerator: { $0 + 1 })
    expectEqual(store1.insert([]), startDate)
    expectEqual(store1.insert(["one"]), startDate + 1)
    expectEqual(store1.insert(["one", "two"]), startDate + 2)
    expectEqual(store1.insert(["one", "two", "three"]), startDate + 3)
    expectEqual(store1.insert(["one", "two", "three", "four"]), startDate + 4)


    var store2 = TicketStore<Date, [String]>(startingAt: startDate, nextTicketGenerator: { $0 + 1 })
    expectEqual(store2.insert([]), startDate)
    expectEqual(store2.insert(["one"]), startDate + 1)
    expectEqual(store2.insert(["one", "two"]), startDate + 2)
    expectEqual(store2.insert(["one", "two", "three"]), startDate + 3)
    expectEqual(store2.insert(["one", "two", "three", "four"]), startDate + 4)

    expectEqual(store1, store2)

    _ = store2.insert([])
    expectNotEqual(store1, store2)
  }

  func test_binarySearch() {
    // 201 and 256 are interesting tests because once we remove the evens, we'll be below the binary search threshold.
    // 1024 seems like a nice round number, and the rest are there to combat programmer bias toward round numbers.
    for size in [201, 256, 499, 1024, 1499] {
      var store = TicketStore<Int, Double>(startingAt: Int.min) // no reason you can't have negative tickets!

      var clientTickets = [Int]()
      clientTickets.reserveCapacity(size)

      for i in 0..<size {
        let ticket = store.insert(Double(i))
        expectEqual(ticket, Int.min + i)
        clientTickets.append(ticket)
        expectTrue(store.contains(ticket))
      }

      expectEqual(store.count, size)

      clientTickets.shuffle()

      for ticket in clientTickets {
        expectTrue(store.contains(ticket))
      }

      expectFalse(store.contains(0))
      expectFalse(store.contains(size))

      // Now confirm binary search works even after we remove some elements
      clientTickets.shuffle()

      let firstOddIdx = clientTickets.partition(by: { $0 % 2 != 0 })
      let oddTickets = clientTickets.suffix(from: firstOddIdx)
      let evenTickets = clientTickets.prefix(firstOddIdx)

      expectEqual(store.count, size)

      for ticket in evenTickets {
        expectNotNil(store.removeValue(forTicket: ticket))
        expectFalse(store.contains(ticket))
      }

      expectEqual(store.count, oddTickets.count)

      for ticket in oddTickets {
        expectTrue(store.contains(ticket))
      }

      for ticket in evenTickets {
        expectFalse(store.contains(ticket))
      }

      let oddTicketsToDrop = oddTickets.prefix(oddTickets.count / 2)
      let remainingOddTickets = oddTickets.suffix(from: oddTicketsToDrop.endIndex)

      for ticket in oddTicketsToDrop {
        expectNotNil(store.removeValue(forTicket: ticket))
        expectFalse(store.contains(ticket))
      }

      expectEqual(store.count, remainingOddTickets.count)

      for ticket in oddTicketsToDrop {
        expectFalse(store.contains(ticket))
      }
    }
  }

  func test_Equatable_Hashable() {
    var store1 = TicketStore<Int, String>()
    expectEqual(store1.insert("a"), 0)
    expectEqual(store1.insert("b"), 1)
    expectEqual(store1.insert("c"), 2)
    expectEqual(store1.insert("d"), 3)
    expectEqual(store1.insert("e"), 4)
    store1.removeValue(forTicket: 0)
    // leaves us with 1=b, 2=c, 3=d, 4=e

    var store2 = TicketStore<Int, String>(startingAt: 1)
    expectEqual(store2.insert("b"), 1)
    expectEqual(store2.insert("c"), 2)
    expectEqual(store2.insert("d"), 3)
    expectEqual(store2.insert("e"), 4)

    var store3 = TicketStore<Int, String>(startingAt: 1)
    expectEqual(store3.insert("b"), 1)
    expectEqual(store3.insert("c"), 2)
    expectEqual(store3.insert("d"), 3)
    expectEqual(store3.insert("e"), 4)
    expectEqual(store3.insert("f"), 5)
    store3.removeValue(forTicket: 5)

    var storeEmptied = TicketStore<Int, String>()
    expectEqual(storeEmptied.insert("a"), 0)
    expectEqual(storeEmptied.insert("b"), 1)
    expectEqual(storeEmptied.insert("c"), 2)
    storeEmptied.removeAll()

    let equivalenceClasses: [[TicketStore<Int, String>]] = [
      [
        store1,
        store2,
        store3,
      ],
      [
        TicketStore<Int, String>(),
        TicketStore<Int, String>(startingAt: -1000),
        TicketStore<Int, String>(startingAt: -1000, nextTicketGenerator: { $0 * 2 }),
        storeEmptied,
      ],
    ]
    checkHashable(equivalenceClasses: equivalenceClasses)
  }

  func test_Sequence() {
    for size in [0, 1, 2, 3, 5, 10] {
      var store = TicketStore<Int, String>(startingAt: size * size)
      expectLessThanOrEqual(store.underestimatedCount, store.count)

      let letters = "abcdefghijklmnopqrstuvwxyz"
      _ = (0..<size).map({ _ in store.insert(String(letters.randomElement()!)) })

      withEvery("underestimatedCount", in: [UnderestimatedCountBehavior.precise, .half, .value(min(1, size))]) { underestimatedCount in
        withEvery("isShared", in: [false, true]) { isShared in
          let sequence = MinimalSequence(elements: store, underestimatedCount: underestimatedCount)
          withHiddenCopies(if: isShared, of: &store) { store in
            expectEqualElements(store, sequence)
          }
        }
      }
    }
  }
}
