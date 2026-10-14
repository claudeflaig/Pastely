import XCTest
@testable import Pastely

final class TabOrderTests: XCTestCase {
    private let a = BarSource.pinboard(UUID())
    private let b = BarSource.pinboard(UUID())
    private let downloads = BarSource.folder("/Users/x/Downloads")

    func testKeepsDefaultOrderWithoutStoredOrder() {
        XCTAssertEqual(TabOrder.sorted([a, b, .cleanShot, downloads], by: []), [a, b, .cleanShot, downloads])
    }

    func testFollowsStoredOrderAndAppendsNewTabs() {
        let order = [downloads, .cleanShot, a].compactMap(TabOrder.key)
        XCTAssertEqual(TabOrder.sorted([a, b, .cleanShot, downloads], by: order), [downloads, .cleanShot, a, b])
    }

    func testMovesFolderAndCleanShotBetweenPinboards() {
        let tabs: [BarSource] = [a, b, .cleanShot, downloads]
        XCTAssertEqual(TabOrder.moving(downloads, onto: a, in: tabs), [downloads, a, b, .cleanShot])
        XCTAssertEqual(TabOrder.moving(.cleanShot, onto: b, in: tabs), [a, .cleanShot, b, downloads])
        XCTAssertEqual(TabOrder.moving(a, onto: downloads, in: tabs), [b, .cleanShot, downloads, a])
    }

    func testHistoryHasNoKey() {
        XCTAssertNil(TabOrder.key(.history))
    }
}
