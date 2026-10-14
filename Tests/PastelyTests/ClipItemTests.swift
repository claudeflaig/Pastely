import XCTest
@testable import Pastely

final class ClipItemTests: XCTestCase {
    func testCodableRoundTripPreservesClipMetadata() throws {
        let original = ClipItem(
            id: UUID(uuidString: "61F39299-3C8E-45AE-90BA-C53889BF9304")!,
            type: .link,
            text: "https://example.com/path",
            sourceBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            customTitle: "Example",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipItem.self, from: encoded)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.displayTitle, "Example")
    }
}

final class HexColorRecognitionTests: XCTestCase {
    func testRecognizesHexCodesWithHash() {
        XCTAssertEqual(ClipItem.hexColor(in: "#CEDCDE"), "#CEDCDE")
        XCTAssertEqual(ClipItem.hexColor(in: " #2b3742\n"), "#2B3742")
        XCTAssertEqual(ClipItem.hexColor(in: "#fa0"), "#FFAA00")
        XCTAssertEqual(ClipItem.hexColor(in: "#2B3742CC"), "#2B3742CC")
    }

    func testLeavesOtherTextAlone() {
        XCTAssertNil(ClipItem.hexColor(in: "bad"))
        XCTAssertNil(ClipItem.hexColor(in: "123456"))
        XCTAssertNil(ClipItem.hexColor(in: "#GGGGGG"))
        XCTAssertNil(ClipItem.hexColor(in: "Farbe #2B3742"))
    }

    func testTextClipBecomesColorClipAndKeepsItsText() {
        let clip = ClipItem(type: .text, text: "#D78B60").recognizingHexColor()
        XCTAssertEqual(clip.type, .color)
        XCTAssertEqual(clip.colorHex, "#D78B60")
        XCTAssertEqual(clip.plainText, "#D78B60")
        XCTAssertEqual(ClipItem(type: .text, text: "Hallo").recognizingHexColor().type, .text)
    }
}
