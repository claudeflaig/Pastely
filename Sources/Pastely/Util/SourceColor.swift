import AppKit
import SwiftUI

@MainActor
enum SourceColor {
    // Paste's saturated header colors.
    private static let palette: [Color] = [
        Color(red: 0.98, green: 0.71, blue: 0.04),
        Color(red: 0.21, green: 0.55, blue: 0.98),
        Color(red: 0.96, green: 0.33, blue: 0.42),
        Color(red: 0.30, green: 0.79, blue: 0.40),
        Color(red: 0.99, green: 0.56, blue: 0.16),
        Color(red: 0.62, green: 0.41, blue: 0.93),
        Color(red: 0.13, green: 0.71, blue: 0.80),
        Color(red: 0.93, green: 0.30, blue: 0.29),
        Color(red: 0.36, green: 0.43, blue: 0.91),
        Color(red: 0.73, green: 0.53, blue: 0.36),
        Color(red: 0.91, green: 0.36, blue: 0.71),
        Color(red: 0.45, green: 0.59, blue: 0.71)
    ]

    private static let key = "appColorMap"
    private static var map: [String: Int] = {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }()

    // Ten deterministic variants of a single user-picked accent color, used
    // by the "Accent shades" theme so every source app keeps a stable,
    // recognizable shade without drifting far from the chosen color.
    private static let accentVariants: [AccentVariant] = [
        AccentVariant(hueOffset: -0.055, saturationOffset:  0.08, brightnessOffset: -0.34),
        AccentVariant(hueOffset:  0.040, saturationOffset: -0.08, brightnessOffset: -0.27),
        AccentVariant(hueOffset: -0.025, saturationOffset:  0.10, brightnessOffset: -0.19),
        AccentVariant(hueOffset:  0.020, saturationOffset: -0.10, brightnessOffset: -0.11),
        AccentVariant(hueOffset: -0.010, saturationOffset:  0.06, brightnessOffset: -0.03),
        AccentVariant(hueOffset:  0.010, saturationOffset: -0.05, brightnessOffset:  0.05),
        AccentVariant(hueOffset: -0.020, saturationOffset:  0.10, brightnessOffset:  0.13),
        AccentVariant(hueOffset:  0.025, saturationOffset: -0.10, brightnessOffset:  0.21),
        AccentVariant(hueOffset: -0.040, saturationOffset:  0.04, brightnessOffset:  0.29),
        AccentVariant(hueOffset:  0.055, saturationOffset: -0.14, brightnessOffset:  0.35)
    ]

    static func color(for bundleID: String?) -> Color {
        switch Settings.shared.clipColorTheme {
        case .default:
            return palette[paletteIndex(for: bundleID)]
        case .vibrant:
            return vibrantPalette[paletteIndex(for: bundleID)]
        case .accentShades:
            return accentShade(
                for: bundleID?.isEmpty == false ? bundleID! : "unknown",
                accentHex: Settings.shared.clipColorAccentHex
            )
        }
    }

    /// The ten deterministic shades for a given accent color, used by
    /// Settings to preview the "Accent shades" theme.
    static func accentShades(for accentHex: String) -> [Color] {
        accentVariants.map { accentShade(variant: $0, accentHex: accentHex) }
    }

    /// A stable palette slot assigned on first sight and persisted, so a given
    /// app keeps its color across launches.
    private static func paletteIndex(for bundleID: String?) -> Int {
        guard let id = bundleID, !id.isEmpty else { return 0 }
        if let i = map[id] { return i % palette.count }
        let i = map.count % palette.count
        map[id] = i
        UserDefaults.standard.set(map, forKey: key)
        return i
    }

    private static let vibrantPalette: [Color] = palette.map { vibrantColor(from: $0) }

    private static func vibrantColor(from color: Color) -> Color {
        guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else { return color }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        // Make the vibrant option visibly distinct while keeping headers dark
        // enough for their white labels to remain readable.
        return Color(
            hue: Double(hue),
            saturation: min(0.99, max(0.92, Double(saturation) * 1.08)),
            brightness: min(0.90, max(0.68, Double(brightness) * 0.90))
        )
    }

    private static func accentShade(for bundleID: String, accentHex: String) -> Color {
        let index = stableIndex(for: bundleID, count: accentVariants.count)
        return accentShade(variant: accentVariants[index], accentHex: accentHex)
    }

    private static var accentBase: (hex: String, hue: Double, saturation: Double, brightness: Double)?

    private static func accentBaseHSB(for accentHex: String) -> (hue: Double, saturation: Double, brightness: Double) {
        if let base = accentBase, base.hex == accentHex {
            return (base.hue, base.saturation, base.brightness)
        }
        let nsColor = NSColor(hex: accentHex)?.usingColorSpace(.sRGB)
            ?? NSColor.systemPink.usingColorSpace(.sRGB)!
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        accentBase = (accentHex, Double(hue), Double(saturation), Double(brightness))
        return (Double(hue), Double(saturation), Double(brightness))
    }

    private static func accentShade(variant: AccentVariant, accentHex: String) -> Color {
        let base = accentBaseHSB(for: accentHex)

        // Normalizing the middle brightness prevents very light or very dark
        // user selections from collapsing several variants into the same color.
        let middleBrightness = min(0.76, max(0.66, base.brightness))
        let adjustedHue = (base.hue + variant.hueOffset + 1).truncatingRemainder(dividingBy: 1)

        return Color(
            hue: adjustedHue,
            saturation: min(0.98, max(0.60, base.saturation + variant.saturationOffset)),
            brightness: min(0.98, max(0.32, middleBrightness + variant.brightnessOffset))
        )
    }

    private static func stableIndex(for bundleID: String, count: Int) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in bundleID.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private struct AccentVariant {
        let hueOffset: Double
        let saturationOffset: Double
        let brightnessOffset: Double
    }
}
