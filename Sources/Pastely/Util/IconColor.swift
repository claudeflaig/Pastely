import AppKit

/// The color an app's icon is known by: its most common vivid hue, toned so
/// white header text stays readable on it. Near-white, near-black and gray
/// pixels are ignored, so Notes reads yellow and Safari blue.
enum IconColor {
    struct Pixel {
        let red, green, blue, alpha: CGFloat
    }

    private static let hueBuckets = 24

    /// The icon's color, or nil when it has too little color to go by.
    @MainActor
    static func of(_ image: NSImage) -> NSColor? {
        dominant(in: pixels(of: image))
    }

    static func dominant(in pixels: [Pixel]) -> NSColor? {
        var weight = [CGFloat](repeating: 0, count: hueBuckets)
        var sums = [(r: CGFloat, g: CGFloat, b: CGFloat, w: CGFloat)](repeating: (0, 0, 0, 0), count: hueBuckets)
        var opaque = 0
        var vivid = 0
        for p in pixels where p.alpha > 0.5 {
            opaque += 1
            let color = NSColor(srgbRed: p.red, green: p.green, blue: p.blue, alpha: 1)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            guard s > 0.28, b > 0.22 else { continue }
            vivid += 1
            let bucket = min(hueBuckets - 1, Int(h * CGFloat(hueBuckets)))
            let w = s * b
            weight[bucket] += w
            sums[bucket].r += p.red * w
            sums[bucket].g += p.green * w
            sums[bucket].b += p.blue * w
            sums[bucket].w += w
        }
        // A mostly gray icon, such as Terminal or System Settings, has no
        // color of its own; one with a small colored detail neither.
        guard opaque > 0, Double(vivid) / Double(opaque) > 0.08,
              let best = weight.indices.max(by: { weight[$0] < weight[$1] }),
              sums[best].w > 0 else { return nil }
        let sum = sums[best]
        let average = NSColor(srgbRed: sum.r / sum.w, green: sum.g / sum.w, blue: sum.b / sum.w, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        average.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return NSColor(hue: h, saturation: min(0.95, max(0.5, s)), brightness: min(0.82, max(0.5, b)), alpha: 1)
    }

    @MainActor
    private static func pixels(of image: NSImage) -> [Pixel] {
        let side = 32
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: side * 4, bitsPerPixel: 32)
        else { return [] }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.bitmapData else { return [] }
        return (0..<(side * side)).map { i in
            let a = CGFloat(data[i * 4 + 3]) / 255
            // Premultiplied: undo it so edge pixels keep their real color.
            let unpremultiply = a > 0 ? 1 / a : 0
            return Pixel(red: min(1, CGFloat(data[i * 4]) / 255 * unpremultiply),
                         green: min(1, CGFloat(data[i * 4 + 1]) / 255 * unpremultiply),
                         blue: min(1, CGFloat(data[i * 4 + 2]) / 255 * unpremultiply),
                         alpha: a)
        }
    }

    // MARK: - Telling apps of one color apart

    /// Which of twelve 30° hue families a color belongs to; -1 for grays.
    static func family(of color: NSColor) -> Int {
        guard let c = color.usingColorSpace(.sRGB) else { return -1 }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        guard s > 0.25 else { return -1 }
        return Int((h * 12 + 0.5).rounded(.down)) % 12
    }

    /// The `index`-th app in a hue family gets a neighboring shade, so five
    /// blue icons become blue, indigo, cyan, navy and violet instead of five
    /// times the same blue. Index 0 keeps the icon's own color.
    static func variant(of color: NSColor, index: Int) -> NSColor {
        guard index > 0, let c = color.usingColorSpace(.sRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        let steps: [(hue: CGFloat, saturation: CGFloat, brightness: CGFloat)] = [
            (0.07, 0.95, 0.62), (-0.06, 1.0, 0.74), (0, 0.85, 0.48),
            (0.12, 0.85, 0.70), (-0.11, 0.9, 0.56), (0.035, 0.7, 0.80)
        ]
        let step = steps[(index - 1) % steps.count]
        // Past the list, nudge a little further so repeats still differ.
        let lap = CGFloat((index - 1) / steps.count) * 0.02
        let hue = (h + step.hue + lap + 1).truncatingRemainder(dividingBy: 1)
        return NSColor(hue: hue, saturation: min(0.95, max(0.3, s * step.saturation)),
                       brightness: step.brightness, alpha: 1)
    }
}
