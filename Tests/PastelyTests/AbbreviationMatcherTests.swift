import XCTest
@testable import Pastely

final class AbbreviationMatcherTests: XCTestCase {
    private func typeAll(_ text: String, _ abbreviations: [String], into matcher: inout AbbreviationMatcher) -> String? {
        var hit: String?
        for ch in text { if let m = matcher.type(String(ch), abbreviations: abbreviations) { hit = m } }
        return hit
    }

    func testFiresAtStartOfWord() {
        var m = AbbreviationMatcher()
        XCTAssertEqual(typeAll("Hallo ;anam", [";anam"], into: &m), ";anam")
        XCTAssertEqual(m.buffer, "")
    }

    func testDoesNotFireInsideWord() {
        var m = AbbreviationMatcher()
        XCTAssertNil(typeAll("x;anam", [";anam"], into: &m))
    }

    func testPrefersLongestOfSimultaneousMatches() {
        var m = AbbreviationMatcher()
        // Both end at the same keystroke; the longer, more specific one wins.
        XCTAssertEqual(typeAll(" ;sig", ["g", ";sig"], into: &m), ";sig")
    }

    func testShorterPrefixFiresFirst() {
        var m = AbbreviationMatcher()
        // Abbreviations should not be prefixes of one another: ";an" fires
        // before ";anam" is finished.
        XCTAssertEqual(typeAll(";anam", [";an", ";anam"], into: &m), ";an")
    }

    func testBackspaceEditsBuffer() {
        var m = AbbreviationMatcher()
        _ = typeAll(";anx", [";anam"], into: &m)
        m.deleteBackward()
        XCTAssertEqual(typeAll("am", [";anam"], into: &m), ";anam")
    }

    func testResetClearsHistory() {
        var m = AbbreviationMatcher()
        _ = typeAll(";an", [";anam"], into: &m)
        m.reset()
        XCTAssertNil(typeAll("am", [";anam"], into: &m))
    }
}
