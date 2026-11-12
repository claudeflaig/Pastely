import AppKit
import SwiftUI

enum Theme {
    // Near-square cards with soft corners, a vivid gradient header carrying
    // the source app's icon, and a quiet body.
    static let cardWidth: CGFloat = 290
    static let cardSpacing: CGFloat = 20
    static let cornerRadius: CGFloat = 22
    static let cardCorner: CGFloat = 18
    static let headerHeight: CGFloat = 56
    static let fileIconSize: CGFloat = 64
    static let appIconSize: CGFloat = 30

    // Every surface color adapts to the bar's light or dark appearance, the
    // way Paste's two themes do.
    static let panelTint = adaptive(light: NSColor.white.withAlphaComponent(0.38),
                                    dark: NSColor.black.withAlphaComponent(0.22))
    static let glassTint = NSColor(name: nil) { appearance in
        isDark(appearance) ? NSColor(white: 0.08, alpha: 0.32) : NSColor.white.withAlphaComponent(0.42)
    }
    static let cardBody = adaptive(light: NSColor(srgbRed: 0.995, green: 0.993, blue: 0.99, alpha: 1),
                                   dark: NSColor(srgbRed: 0.155, green: 0.152, blue: 0.15, alpha: 1))
    static let cardBorder = adaptive(light: NSColor.black.withAlphaComponent(0.06),
                                     dark: NSColor.white.withAlphaComponent(0.08))
    /// The hairline around a card: a little stronger on light glass, where a
    /// white card would otherwise dissolve into the bar.
    static let cardHairline = adaptive(light: NSColor.black.withAlphaComponent(0.09),
                                       dark: NSColor.white.withAlphaComponent(0.10))
    /// The light catching a card's top edge, as on glass.
    static let cardSheen = adaptive(light: NSColor.white.withAlphaComponent(0.70),
                                    dark: NSColor.white.withAlphaComponent(0.22))
    static let cardShadow = adaptive(light: NSColor.black.withAlphaComponent(0.10),
                                     dark: NSColor.black.withAlphaComponent(0.34))

    /// The Glass theme's card: barely there, so the bar shows through.
    static let glassCard = adaptive(light: NSColor.white.withAlphaComponent(0.62),
                                    dark: NSColor.white.withAlphaComponent(0.07))
    /// The Paper theme's card: warm off-white, or warm ink in the dark.
    static let paper = adaptive(light: NSColor(srgbRed: 0.988, green: 0.976, blue: 0.953, alpha: 1),
                                dark: NSColor(srgbRed: 0.137, green: 0.129, blue: 0.122, alpha: 1))
    static let paperSpine: CGFloat = 4

    static let selection = Color(red: 0.16, green: 0.50, blue: 0.98)
    /// The selected card gets a focus ring that stands slightly off the card,
    /// with a soft glow around it.
    static let selectedCardRing: CGFloat = 2.5
    static let selectionRingGap: CGFloat = 3
    static let selectionGlowRadius: CGFloat = 10
    /// How far a hovered card lifts.
    static let cardHoverLift: CGFloat = 3
    /// How far the selection reaches past the card: ring, gap and glow.
    static let selectionOutset: CGFloat = selectedCardRing + selectionRingGap + selectionGlowRadius
    // Leave 43 pt beyond the selected-card ring at either strip edge while
    // preserving the ScrollView's normal clipping behavior.
    static let cardStripHorizontalPadding: CGFloat = selectedCardRing + selectionRingGap + 43
    /// The strip does not clip, so the glow may spill into the tabs above;
    /// the padding only keeps the ring and a hovered card clear of them.
    static let cardStripTopPadding: CGFloat = selectedCardRing + selectionRingGap + cardHoverLift + 4
    static let cardStripBottomPadding: CGFloat = max(26, selectionOutset + 8)

    static let chromeTextPrimary = graphite(0.88)
    static let chromeTextSecondary = graphite(0.55)
    static let chromeTextTertiary = graphite(0.32)

    static let cardTextPrimary = graphite(0.86)
    static let cardTextSecondary = graphite(0.48)
    static let cardTextTertiary = graphite(0.30)

    static let headerText = Color.white
    static let headerSubText = Color.white.opacity(0.85)

    static let fieldBG = ink(0.07)
    static let pillBG = Color.clear
    static let pillSelected = ink(0.08)
    static let pillHover = ink(0.14)

    /// Black washes on light surfaces, white on dark ones, for fills.
    private static func ink(_ opacity: CGFloat) -> Color {
        adaptive(light: NSColor.black.withAlphaComponent(opacity),
                 dark: NSColor.white.withAlphaComponent(opacity))
    }

    /// Text in warm graphite: a brown-tinted near-black on light surfaces and
    /// a warm off-white on dark ones, instead of neutral black and white.
    private static func graphite(_ opacity: CGFloat) -> Color {
        Color(nsColor: graphiteNS(opacity))
    }

    static func graphiteNS(_ opacity: CGFloat) -> NSColor {
        let light = NSColor(srgbRed: 0.18, green: 0.16, blue: 0.14, alpha: 1)
        let dark = NSColor(srgbRed: 0.98, green: 0.95, blue: 0.91, alpha: 1)
        return NSColor(name: nil) {
            (isDark($0) ? dark : light).withAlphaComponent(opacity)
        }
    }

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { isDark($0) ? dark : light })
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

extension Date {
    var clipRelative: String {
        let secs = -timeIntervalSinceNow
        switch secs {
        case ..<5:        return "Now"
        case ..<60:       return "\(Int(secs))s"
        case ..<3600:     return "\(Int(secs / 60))m"
        case ..<86_400:   return "\(Int(secs / 3600))h"
        case ..<604_800:  return "\(Int(secs / 86_400))d"
        default:
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: self)
        }
    }

    var clipRelativeLong: String {
        let secs = -timeIntervalSinceNow
        if secs < 8 { return "Just now" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: self, relativeTo: Date())
    }
}
