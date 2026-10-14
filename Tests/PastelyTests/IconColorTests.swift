import AppKit
import XCTest
@testable import Pastely

final class IconColorTests: XCTestCase {
    private func pixels(_ count: Int, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, alpha: CGFloat = 1) -> [IconColor.Pixel] {
        Array(repeating: IconColor.Pixel(red: r, green: g, blue: b, alpha: alpha), count: count)
    }

    func testPicksTheMostCommonVividHueOverWhiteAndGray() {
        let icon = pixels(500, 1, 1, 1) + pixels(300, 0.5, 0.5, 0.5) + pixels(200, 0.1, 0.4, 0.95)
            + pixels(40, 0.95, 0.2, 0.2)
        let color = IconColor.dominant(in: icon)?.usingColorSpace(.sRGB)
        XCTAssertNotNil(color)
        XCTAssertGreaterThan(color!.blueComponent, color!.redComponent)
    }

    func testGrayIconHasNoColor() {
        XCTAssertNil(IconColor.dominant(in: pixels(900, 0.3, 0.3, 0.3) + pixels(100, 1, 1, 1)))
    }

    func testIgnoresTransparentPixels() {
        let icon = pixels(800, 1, 0.8, 0, alpha: 0) + pixels(200, 0.2, 0.7, 0.2)
        let color = IconColor.dominant(in: icon)?.usingColorSpace(.sRGB)
        XCTAssertGreaterThan(color!.greenComponent, color!.redComponent)
    }

    func testKeepsColorDarkEnoughForWhiteText() {
        var b: CGFloat = 0
        IconColor.dominant(in: pixels(100, 1, 0.95, 0.4))?.getHue(nil, saturation: nil, brightness: &b, alpha: nil)
        XCTAssertLessThanOrEqual(b, 0.82)
    }
}
