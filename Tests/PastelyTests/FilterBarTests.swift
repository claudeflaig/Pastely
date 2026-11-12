import XCTest
@testable import Pastely

@MainActor
final class FilterBarTests: XCTestCase {
    func testFilterButtonHidesTheRowEvenWhileSearchingOrFiltering() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FilterBarTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ClipboardStore(baseDirectory: dir)

        store.barInputMode = .search
        XCTAssertTrue(store.showsFilterBar, "starting a search brings the filters along")

        store.filter = ClipFilter(kinds: [.text])
        store.toggleFilterBar()
        XCTAssertFalse(store.showsFilterBar, "the Filter button hides the row with a filter on")
        XCTAssertTrue(store.filter.isActive, "hiding the row keeps the filter")

        store.barInputMode = .cards
        store.barInputMode = .search
        XCTAssertFalse(store.showsFilterBar, "refocusing the same search keeps it hidden")

        store.toggleFilterBar()
        XCTAssertTrue(store.showsFilterBar)

        store.toggleFilterBar()
        store.resetFilterBar()
        store.barInputMode = .cards
        store.barInputMode = .search
        XCTAssertTrue(store.showsFilterBar, "a new search shows it again")
    }
}
