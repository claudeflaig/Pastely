import AppKit

// Turns the artwork in packaging/AppIcon-source.png into a 1024 px macOS app
// icon: the tile is found by trimming the dark surround, then drawn at
// Apple's 824 px icon size, centered and clipped to the rounded tile so the
// corners are transparent.
let args = CommandLine.arguments
let source = NSImage(contentsOfFile: args[1])!
let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let rep = NSBitmapImageRep(cgImage: cg)

func isTile(_ x: Int, _ y: Int) -> Bool {
    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
    return c.redComponent + c.greenComponent + c.blueComponent > 0.25
}

// Scan inward along the middle row and column for the tile's edges.
let w = rep.pixelsWide, h = rep.pixelsHigh
let midY = h / 2, midX = w / 2
let left = (0..<w).first { isTile($0, midY) } ?? 0
let right = (0..<w).reversed().first { isTile($0, midY) } ?? w - 1
let top = (0..<h).first { isTile(midX, $0) } ?? 0
let bottom = (0..<h).reversed().first { isTile(midX, $0) } ?? h - 1
let crop = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
let tile = cg.cropping(to: crop)!

let canvas = 1024.0, size = 824.0, inset = (canvas - size) / 2
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
let rect = NSRect(x: inset, y: inset, width: size, height: size)
// A soft drop shadow like the system's icons.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 20
NSGraphicsContext.current?.saveGraphicsState()
shadow.set()
NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225).fill()
NSGraphicsContext.current?.restoreGraphicsState()
NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225).addClip()
// Overscan slightly so no dark edge of the source survives the clip.
NSImage(cgImage: tile, size: .zero).draw(in: rect.insetBy(dx: -size * 0.012, dy: -size * 0.012))
NSGraphicsContext.restoreGraphicsState()
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("tile \(crop)")
