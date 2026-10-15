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

final class IconColorVariantTests: XCTestCase {
    private let blue = NSColor(srgbRed: 0.04, green: 0.5, blue: 0.82, alpha: 1)

    func testFirstAppKeepsItsColor() {
        XCTAssertEqual(IconColor.variant(of: blue, index: 0), blue)
    }

    func testLaterAppsOfTheSameFamilyDiffer() {
        let colors = (0..<6).map { IconColor.variant(of: blue, index: $0).usingColorSpace(.sRGB)! }
        for i in colors.indices {
            for j in colors.indices where j > i {
                let distance = abs(colors[i].redComponent - colors[j].redComponent)
                    + abs(colors[i].greenComponent - colors[j].greenComponent)
                    + abs(colors[i].blueComponent - colors[j].blueComponent)
                XCTAssertGreaterThan(distance, 0.12, "variants \(i) and \(j) look alike")
            }
        }
    }

    func testFamiliesSeparateBlueFromOrangeAndGray() {
        XCTAssertNotEqual(IconColor.family(of: blue), IconColor.family(of: .orange))
        XCTAssertEqual(IconColor.family(of: NSColor(white: 0.5, alpha: 1)), -1)
    }
}
