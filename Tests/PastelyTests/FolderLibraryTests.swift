import XCTest
@testable import Pastely

final class FolderLibraryTests: XCTestCase {
    @MainActor
    func testListsNewestFirstAndSkipsHidden() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for (name, age) in [("old.pdf", 300.0), ("new.png", 10.0), (".hidden", 1.0)] {
            let url = dir.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)],
                                                  ofItemAtPath: url.path)
        }
        let library = FolderLibrary.shared
        library.refresh(dir.path)
        let names = library.items(in: dir.path).map(\.text)
        XCTAssertFalse(names.contains(".hidden"))
        XCTAssertEqual(Set(names.compactMap { $0 }), ["old.pdf", "new.png"])
        XCTAssertTrue(library.items(in: dir.path).allSatisfy { $0.type == .file })
    }
}

final class FolderArrivalTests: XCTestCase {
    @MainActor
    func testSkipsHiddenAndUnfinishedDownloads() {
        let names: Set<String> = ["Rechnung.pdf", ".DS_Store", "film.mp4.crdownload",
                                  "bericht.pdf.download", "foto.jpg.part", "Bild.png"]
        XCTAssertEqual(FolderLibrary.newArrivals(names), ["Rechnung.pdf", "Bild.png"])
    }
}
