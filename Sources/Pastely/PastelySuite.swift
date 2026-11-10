#if SUITE
import AppKit
import SwiftUI

/// Entry points for MacSuite, which also runs Screeny and Whispy in this
/// process. The suite's own menu bar icon stands in for Pastely's status item,
/// and its one Settings window shows Pastely's panes, so it calls them
/// through here.
@MainActor
public enum PastelySuite {
    public static func makeAppDelegate() -> NSApplicationDelegate { AppController.shared }

    public static var hotkeyDisplay: String { Settings.shared.hotkeyDisplay }
    public static var pasteStackHotkeyDisplay: String { Settings.shared.pasteStackHotkeyDisplay }
    public static var captureTextHotkeyDisplay: String { Settings.shared.captureTextHotkeyDisplay }
    public static var isPaused: Bool { AppController.shared.monitor.isPaused }

    /// One of Pastely's shortcuts, for the suite's overview of all shortcuts.
    public struct Shortcut {
        public let title: String
        public let subtitle: String
        public let symbol: String
        /// As Pastely shows it, e.g. "⇧⌘V".
        public let display: String
        /// False while the shortcut is turned off in Settings.
        public let isEnabled: Bool
        /// Whether the keys work everywhere or only while the bar is open.
        public let isGlobal: Bool
        /// The `SettingsPane` raw value where it is changed.
        public let pane: String
    }

    public static var shortcuts: [Shortcut] {
        let s = Settings.shared
        var result: [Shortcut] = [
            .init(title: "Verlauf öffnen", subtitle: "Die Leiste mit allem Kopierten.",
                  symbol: "doc.on.clipboard", display: s.hotkeyDisplay,
                  isEnabled: true, isGlobal: true, pane: "shortcuts"),
            .init(title: "Paste Stack", subtitle: "Mehrere Kopien sammeln, der Reihe nach einfügen.",
                  symbol: "square.stack.3d.up", display: s.pasteStackHotkeyDisplay,
                  isEnabled: s.pasteStackShortcut, isGlobal: true, pane: "pasteStack"),
        ]
        #if !MAS
        result += [
            .init(title: "Als reinen Text einfügen", subtitle: "Die Zwischenablage ohne Formatierung.",
                  symbol: "textformat", display: s.plainTextPasteHotkeyDisplay,
                  isEnabled: s.plainTextPasteShortcut, isGlobal: true, pane: "shortcuts"),
            .init(title: "Text erfassen", subtitle: "Text vom Bildschirm in den Verlauf.",
                  symbol: "text.viewfinder", display: s.captureTextHotkeyDisplay,
                  isEnabled: s.captureTextShortcut, isGlobal: true, pane: "shortcuts"),
        ]
        #endif
        let quick = s.quickPasteModifierDisplay
        let plain = ShortcutModifier(carbonValue: s.plainTextModifier)?.symbol ?? "⇧"
        result += [
            .init(title: "Eintrag 1–9 einfügen", subtitle: "Während die Leiste offen ist.",
                  symbol: "number", display: "\(quick)1…9",
                  isEnabled: true, isGlobal: false, pane: "shortcuts"),
            .init(title: "Eintrag 1–9 als reinen Text", subtitle: "Während die Leiste offen ist.",
                  symbol: "textformat.123", display: "\(quick)\(plain)1…9",
                  isEnabled: true, isGlobal: false, pane: "shortcuts"),
        ]
        return result
    }

    public static func openBar() { AppController.shared.showBar() }
    public static func togglePasteStack() { PasteStack.shared.toggle() }
    public static func captureText() { AppController.shared.captureScreenText() }
    public static func showSettings() { AppController.shared.showSettings() }
    public static func togglePause() { AppController.shared.togglePastelyPause() }
    public static func clearHistory() { ClipboardStore.shared.clearHistory() }

    /// Set by the suite: opens its Settings window on Pastely's panes instead
    /// of Pastely's own window.
    public static var onShowSettings: (() -> Void)?

    /// The rows of one Settings pane, by `SettingsPane` raw value, without
    /// Pastely's sidebar and header.
    public static func settingsPane(_ id: String) -> AnyView {
        guard let pane = SettingsPane(rawValue: id) else { return AnyView(EmptyView()) }
        return AnyView(SettingsPaneContent(pane: pane))
    }
}
#endif
