import XCTest
@testable import Pesty

final class ClipFilterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func file(_ path: String) -> ClipItem {
        ClipItem(type: .file, text: path, fileURLs: [URL(fileURLWithPath: path).absoluteString])
    }

    func testKindsGroupClipTypesTheWayPasteDoes() {
        XCTAssertEqual(ClipKind.of(ClipItem(type: .richText, text: "x")), .text)
        XCTAssertEqual(ClipKind.of(ClipItem(type: .link, text: "https://a.b")), .link)
        XCTAssertEqual(ClipKind.of(ClipItem(type: .color, colorHex: "#FFFFFF")), .color)
        XCTAssertEqual(ClipKind.of(ClipItem(type: .image, imageFileName: "a.png")), .image)
        XCTAssertEqual(ClipKind.of(file("/tmp/CleanShot 2026-10-14 at 21.00.png")), .screenshot)
        XCTAssertEqual(ClipKind.of(file("/tmp/holiday.jpg")), .image)
        XCTAssertEqual(ClipKind.of(file("/tmp/report.pdf")), .file)
    }

    func testEmptyFilterMatchesEverything() {
        let filter = ClipFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertTrue(filter.matches(ClipItem(type: .text, text: "a"), now: now, calendar: calendar))
    }

    func testKindFilterAcceptsAnyChosenKind() {
        let filter = ClipFilter(kinds: [.link, .screenshot])
        XCTAssertTrue(filter.matches(ClipItem(type: .link, text: "https://a.b"), now: now))
        XCTAssertTrue(filter.matches(file("/tmp/Screenshot 2026-10-14.png"), now: now))
        XCTAssertFalse(filter.matches(ClipItem(type: .text, text: "a"), now: now))
        XCTAssertFalse(filter.matches(file("/tmp/holiday.jpg"), now: now))
    }

    func testAppFilterMatchesSourceBundle() {
        let filter = ClipFilter(appBundleID: "com.apple.Safari", appName: "Safari")
        XCTAssertTrue(filter.matches(ClipItem(type: .text, text: "a", sourceBundleID: "com.apple.Safari"), now: now))
        XCTAssertFalse(filter.matches(ClipItem(type: .text, text: "a", sourceBundleID: "com.apple.Notes"), now: now))
        XCTAssertFalse(filter.matches(ClipItem(type: .text, text: "a"), now: now))
    }

    func testDateRanges() {
        let startOfToday = calendar.startOfDay(for: now)
        let earlierToday = ClipItem(type: .text, text: "a", createdAt: startOfToday.addingTimeInterval(60))
        let yesterday = ClipItem(type: .text, text: "a", createdAt: startOfToday.addingTimeInterval(-60))
        let tenDaysAgo = ClipItem(type: .text, text: "a", createdAt: now.addingTimeInterval(-10 * 86_400))
        let fortyDaysAgo = ClipItem(type: .text, text: "a", createdAt: now.addingTimeInterval(-40 * 86_400))

        let today = ClipFilter(dateRange: .today)
        XCTAssertTrue(today.matches(earlierToday, now: now, calendar: calendar))
        XCTAssertFalse(today.matches(yesterday, now: now, calendar: calendar))

        let week = ClipFilter(dateRange: .lastWeek)
        XCTAssertTrue(week.matches(yesterday, now: now, calendar: calendar))
        XCTAssertFalse(week.matches(tenDaysAgo, now: now, calendar: calendar))

        let month = ClipFilter(dateRange: .lastMonth)
        XCTAssertTrue(month.matches(tenDaysAgo, now: now, calendar: calendar))
        XCTAssertFalse(month.matches(fortyDaysAgo, now: now, calendar: calendar))
    }

    func testDimensionsCombine() {
        let filter = ClipFilter(kinds: [.text], appBundleID: "com.apple.Notes", dateRange: .today)
        let match = ClipItem(type: .text, text: "a", sourceBundleID: "com.apple.Notes", createdAt: now)
        let wrongApp = ClipItem(type: .text, text: "a", sourceBundleID: "com.apple.Safari", createdAt: now)
        let wrongKind = ClipItem(type: .link, text: "https://a.b", sourceBundleID: "com.apple.Notes", createdAt: now)
        XCTAssertTrue(filter.matches(match, now: now, calendar: calendar))
        XCTAssertFalse(filter.matches(wrongApp, now: now, calendar: calendar))
        XCTAssertFalse(filter.matches(wrongKind, now: now, calendar: calendar))
    }

    func testAppsAreListedByFrequency() {
        let items = [
            ClipItem(type: .text, text: "a", sourceBundleID: "com.apple.Notes", sourceAppName: "Notes"),
            ClipItem(type: .text, text: "b", sourceBundleID: "com.apple.Safari", sourceAppName: "Safari"),
            ClipItem(type: .text, text: "c", sourceBundleID: "com.apple.Safari", sourceAppName: "Safari"),
            ClipItem(type: .text, text: "d"),
        ]
        let apps = ClipFilter.apps(in: items)
        XCTAssertEqual(apps.map(\.bundleID), ["com.apple.Safari", "com.apple.Notes"])
        XCTAssertEqual(apps.first?.name, "Safari")
    }
}
