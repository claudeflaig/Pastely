import XCTest
@testable import Pastely

final class PinboardArchiveTests: XCTestCase {
    func testRoundTrip() throws {
        let archive = PinboardArchive(pinboards: [
            .init(name: "Vorlagen", colorHex: "#FF5F57", items: [
                .init(type: "text", title: "Absage", text: "Liebe Yvonne …"),
                .init(type: "color", colorHex: "#5B8DEF"),
            ])
        ])
        let decoded = try PinboardArchive.decode(archive.encoded())
        XCTAssertEqual(decoded, archive)
    }

    func testRejectsForeignJSON() {
        XCTAssertThrowsError(try PinboardArchive.decode(Data(#"{"format":"other","version":1,"pinboards":[]}"#.utf8)))
    }

    func testItemsBecomeClips() {
        let text = PinboardArchive.clip(from: .init(type: "text", title: "Gruss", text: "Hallo"))
        XCTAssertEqual(text?.0.type, .text)
        XCTAssertEqual(text?.0.customTitle, "Gruss")
        // An unknown type with text still comes through as text.
        XCTAssertEqual(PinboardArchive.clip(from: .init(type: "snippet", text: "x"))?.0.type, .text)
        XCTAssertNil(PinboardArchive.clip(from: .init(type: "snippet")))
    }
}
