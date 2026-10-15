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

final class ShelfTextFileTests: XCTestCase {
    func testFileNameIsTheFirstLineMadeSafe() {
        XCTAssertEqual(ShelfTextFile.fileName(for: "Shelf-Test eins", fallback: "Text"), "Shelf-Test eins")
        XCTAssertEqual(ShelfTextFile.fileName(for: "a/b: c\nzweite Zeile", fallback: "Text"), "a-b- c")
        XCTAssertEqual(ShelfTextFile.fileName(for: "   \n", fallback: "Text"), "Text")
        XCTAssertEqual(ShelfTextFile.fileName(for: String(repeating: "x", count: 100), fallback: "Text").count, 60)
    }

    func testTakenNameGetsANumber() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Notiz.txt")
        XCTAssertEqual(ShelfTextFile.freeURL(near: url), url)
        try Data().write(to: url)
        XCTAssertEqual(ShelfTextFile.freeURL(near: url).lastPathComponent, "Notiz 2.txt")
    }
}
