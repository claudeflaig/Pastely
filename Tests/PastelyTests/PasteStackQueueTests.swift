import XCTest
@testable import Pastely

final class PasteStackQueueTests: XCTestCase {
    private func text(_ s: String) -> ClipItem { ClipItem(type: .text, text: s) }

    func testPastesInCopyOrder() {
        var queue = PasteStackQueue()
        queue.add(text("a")); queue.add(text("b")); queue.add(text("c"))
        XCTAssertEqual(queue.next?.text, "a")
        XCTAssertEqual(queue.popNext()?.text, "a")
        XCTAssertEqual(queue.next?.text, "b")
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["b", "c"])
    }

    func testReversedPastesNewestFirst() {
        var queue = PasteStackQueue()
        queue.add(text("a")); queue.add(text("b")); queue.add(text("c"))
        queue.reversed = true
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["c", "b", "a"])
        XCTAssertEqual(queue.popNext()?.text, "c")
        XCTAssertEqual(queue.next?.text, "b")
    }

    func testCopyingAgainMovesInsteadOfDuplicating() {
        var queue = PasteStackQueue()
        queue.add(text("a")); queue.add(text("b"))
        queue.add(text("a"))
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["b", "a"])
        XCTAssertEqual(queue.count, 2)
    }

    func testRemoveAndEmpty() {
        var queue = PasteStackQueue()
        let a = text("a")
        queue.add(a); queue.add(text("b"))
        queue.remove(id: a.id)
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["b"])
        queue.popNext()
        XCTAssertTrue(queue.isEmpty)
        XCTAssertNil(queue.popNext())
        XCTAssertNil(queue.next)
    }
}

final class PasteStackReorderTests: XCTestCase {
    private func clip(_ text: String) -> ClipItem { ClipItem(type: .text, text: text) }

    func testDraggedCardTakesTheDropSpot() {
        var queue = PasteStackQueue()
        let a = clip("a"), b = clip("b"), c = clip("c")
        [a, b, c].forEach { queue.add($0) }
        queue.move(id: c.id, onto: a.id)
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["c", "a", "b"])
        queue.move(id: c.id, onto: b.id)
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["a", "b", "c"])
    }

    func testReorderFollowsThePasteOrderWhenReversed() {
        var queue = PasteStackQueue()
        let a = clip("a"), b = clip("b"), c = clip("c")
        [a, b, c].forEach { queue.add($0) }
        queue.reversed = true
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["c", "b", "a"])
        queue.move(id: a.id, onto: c.id)
        XCTAssertEqual(queue.pasteOrder.map(\.text), ["a", "c", "b"])
        XCTAssertEqual(queue.next?.text, "a")
    }
}
