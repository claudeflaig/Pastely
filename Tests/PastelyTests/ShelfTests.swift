import XCTest
@testable import Pastely

@MainActor
final class ShelfTests: XCTestCase {
    private func file(_ name: String) -> ClipItem {
        ClipItem(type: .file, text: name, fileURLs: ["file:///tmp/\(name)"])
    }

    func testTitleNamesTheKindAndCount() {
        XCTAssertEqual(ShelfModel.title(for: [file("a.txt"), file("b.pdf")]), "2 Documents")
        XCTAssertEqual(ShelfModel.title(for: [file("a.png")]), "1 Image")
        XCTAssertEqual(ShelfModel.title(for: [file("a.txt"), ClipItem(type: .text, text: "Hallo")]), "2 Items")
    }

    func testSameCopyAgainDoesNotDouble() {
        let model = ShelfModel()
        model.add(ClipItem(type: .text, text: "Hallo"))
        model.add(ClipItem(type: .text, text: "Hallo"))
        XCTAssertEqual(model.items.count, 1)
    }

    func testRemovingTheDraggedItemsKeepsTheRest() {
        let model = ShelfModel()
        let a = file("a.txt"), b = file("b.txt")
        model.add(a); model.add(b)
        model.remove([a])
        XCTAssertEqual(model.items.map(\.id), [b.id])
    }
}
