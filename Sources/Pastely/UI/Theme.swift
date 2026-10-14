import AppKit
import SwiftUI

enum Theme {
    // Proportions and colors follow Paste: near-square cards with small
    // corners, a vivid header, a pure white body and dark chrome on a light,
    // frosted bar.
    static let cardWidth: CGFloat = 290
    static let cardSpacing: CGFloat = 20
    static let cornerRadius: CGFloat = 22
    static let cardCorner: CGFloat = 12
    static let headerHeight: CGFloat = 62
    static let fileIconSize: CGFloat = 64
    static let appIconSize: CGFloat = 66

    // Every surface color adapts to the bar's light or dark appearance, the
    // way Paste's two themes do.
    static let panelTint = adaptive(light: NSColor.white.withAlphaComponent(0.38),
                                    dark: NSColor.black.withAlphaComponent(0.22))
    static let glassTint = NSColor(name: nil) { appearance in
        isDark(appearance) ? NSColor(white: 0.08, alpha: 0.32) : NSColor.white.withAlphaComponent(0.42)
    }
    static let cardBody = adaptive(light: .white, dark: NSColor(white: 0.17, alpha: 1))
    static let cardBorder = adaptive(light: NSColor.black.withAlphaComponent(0.06),
                                     dark: NSColor.white.withAlphaComponent(0.08))
    static let selection = Color(red: 0.16, green: 0.50, blue: 0.98)
    static let selectedCardRing: CGFloat = 4
    // Leave 43 pt beyond the selected-card ring at either strip edge while
    // preserving the ScrollView's normal clipping behavior.
    static let cardStripHorizontalPadding: CGFloat = selectedCardRing + 43

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
