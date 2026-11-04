#if SUITE
import AppKit

/// Entry points for the Pastely suite, which also runs Screeny and Whispy in
/// this process. Whispy's menu bar icon stands in for Pastely's status item, so
/// the suite calls the status menu's actions through here.
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
}
#endif
