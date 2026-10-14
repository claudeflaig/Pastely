import XCTest
@testable import Pastely

/// Runs against a copy of a real Pasty database when PASTY_DB points at one;
/// the database is personal data, so none ships with the tests.
final class PastyImporterTests: XCTestCase {
    @MainActor
    func testConvertsPastyPinboards() throws {
        guard let path = ProcessInfo.processInfo.environment["PASTY_DB"] else {
            throw XCTSkip("Set PASTY_DB to a copy of Pasta.sqlite")
        }
        let archive = try PastyImporter.archive(fromDatabase: URL(fileURLWithPath: path))
        XCTAssertFalse(archive.pinboards.contains { $0.name == "History" })
        let items = archive.pinboards.flatMap(\.items)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { $0.text != nil || $0.imagePNG != nil || $0.fileURLs != nil })
        print("PASTY", archive.pinboards.map { "\($0.name)=\($0.items.count)" }.joined(separator: ", "),
              "| titled:", items.filter { $0.title != nil }.count,
              "| types:", Dictionary(grouping: items, by: \.type).mapValues(\.count))
    }
}
