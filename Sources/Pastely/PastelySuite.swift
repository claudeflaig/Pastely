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
