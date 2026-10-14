import XCTest
@testable import Pesty

final class ScreenshotDetectorTests: XCTestCase {
    func testRecognizesCaptureFileNames() {
        XCTAssertTrue(ScreenshotDetector.isScreenshot(URL(fileURLWithPath: "/tmp/CleanShot 2026-10-09 at 21.10.02@2x.png")))
        XCTAssertTrue(ScreenshotDetector.isScreenshot(URL(fileURLWithPath: "/tmp/Bildschirmfoto 2026-10-14 um 21.44.png")))
        XCTAssertTrue(ScreenshotDetector.isScreenshot(URL(fileURLWithPath: "/tmp/Screenshot 2026-10-14 at 9.41.png")))
    }

    func testCleanShotMediaFolderCountsAsScreenshot() {
        let url = URL(fileURLWithPath: "/Users/x/Library/Application Support/CleanShot/media/media_ab/photo.png")
        XCTAssertTrue(ScreenshotDetector.isScreenshot(url))
    }

    func testOrdinaryImagesAreNotScreenshots() {
        XCTAssertFalse(ScreenshotDetector.isScreenshot(URL(fileURLWithPath: "/tmp/holiday.jpg")))
    }
}
