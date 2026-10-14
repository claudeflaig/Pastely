import XCTest
@testable import Pesty

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
