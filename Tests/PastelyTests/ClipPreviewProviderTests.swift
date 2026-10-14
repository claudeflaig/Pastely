import XCTest
@testable import Pastely

@MainActor
final class ClipPreviewProviderTests: XCTestCase {
    func testOnlySingleImageFilesShowAsImages() {
        let png = ClipItem(type: .file, fileURLs: ["file:///tmp/shot.png"])
        let pdf = ClipItem(type: .file, fileURLs: ["file:///tmp/report.pdf"])
        let two = ClipItem(type: .file, fileURLs: ["file:///tmp/a.png", "file:///tmp/b.png"])

        XCTAssertEqual(ClipPreviewProvider.imageFileURL(for: png)?.path, "/tmp/shot.png")
        XCTAssertNil(ClipPreviewProvider.imageFileURL(for: pdf))
        XCTAssertNil(ClipPreviewProvider.imageFileURL(for: two))
        XCTAssertTrue(ClipPreviewProvider.showsImage(ClipItem(type: .image, imageFileName: "x.png")))
        XCTAssertFalse(ClipPreviewProvider.showsImage(pdf))
    }

    func testFileInfoReportsMissingFilesOnlyOnENOENT() async {
        let present = ClipItem(type: .file, fileURLs: ["file:///bin/ls"])
        let gone = ClipItem(type: .file, fileURLs: ["file:///nonexistent/\(UUID().uuidString).pdf"])

        let presentInfo = await ClipPreviewProvider.fileInfo(for: present)
        XCTAssertEqual(presentInfo?.isMissing, false)
        XCTAssertNotNil(presentInfo?.icon)

        let goneInfo = await ClipPreviewProvider.fileInfo(for: gone)
        XCTAssertEqual(goneInfo?.isMissing, !ClipboardStore.isSandboxed)
        XCTAssertNotNil(goneInfo?.icon)

        let text = await ClipPreviewProvider.fileInfo(for: ClipItem(type: .text, text: "x"))
        XCTAssertNil(text)
    }
}

@MainActor
final class ImageCanvasFitTests: XCTestCase {
    private let canvas = CGSize(width: 290, height: 230)

    func testImageCloseToCardShapeFills() {
        XCTAssertTrue(ClipCardView.imageFillsCanvas(CGSize(width: 1254, height: 1254), canvas: canvas))
        XCTAssertTrue(ClipCardView.imageFillsCanvas(CGSize(width: 1600, height: 1200), canvas: canvas))
    }

    func testWideAndTallImagesAreShownWhole() {
        XCTAssertFalse(ClipCardView.imageFillsCanvas(CGSize(width: 3000, height: 600), canvas: canvas))
        XCTAssertFalse(ClipCardView.imageFillsCanvas(CGSize(width: 1170, height: 2532), canvas: canvas))
    }
}
