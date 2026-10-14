import AppKit
import Carbon.HIToolbox

/// Keeps the last characters typed and reports when they end in one of the
/// abbreviations. Pure logic, kept apart from the event plumbing below.
struct AbbreviationMatcher {
    private(set) var buffer = ""
    private static let capacity = 64

    mutating func reset() { buffer = "" }

    mutating func deleteBackward() {
        if !buffer.isEmpty { buffer.removeLast() }
    }

    /// Appends typed text and returns the abbreviation it completes, if any.
    /// An abbreviation only counts at the start of a word, so ";anam" fires
    /// but "x;anam" does not.
    mutating func type(_ text: String, abbreviations: [String]) -> String? {
        buffer += text
        if buffer.count > Self.capacity { buffer.removeFirst(buffer.count - Self.capacity) }
        let match = abbreviations
            .filter { !$0.isEmpty && buffer.hasSuffix($0) }
            .max { $0.count < $1.count }
        guard let match else { return nil }
        let before = buffer.dropLast(match.count).last
        guard before == nil || before!.isWhitespace || before!.isPunctuation && !match.first!.isPunctuation
                || before!.isNewline else { return nil }
        buffer = ""
        return match
    }
}

#if !MAS
/// Replaces an abbreviation with its clip as you type anywhere, like a text
/// expander. It watches keystrokes system-wide, which macOS allows only with
/// the Accessibility permission, removes the typed abbreviation with
/// backspaces, pastes the clip and then puts the previous clipboard back.
@MainActor
final class TextExpander {
    static let shared = TextExpander()

    private var matcher = AbbreviationMatcher()
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var expanding = false

    private init() {}

    func refresh() {
        let wanted = Settings.shared.expandAbbreviations && !ClipboardStore.shared.abbreviatedClips.isEmpty
        if wanted, keyMonitor == nil { start() }
        if !wanted, keyMonitor != nil { stop() }
    }

    private func start() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { TextExpander.shared.handle(event) }
        }
        // A click moves the caret, so what was typed before no longer leads up to it.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated { TextExpander.shared.matcher.reset() }
        }
    }

    private func stop() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        keyMonitor = nil
        mouseMonitor = nil
        matcher.reset()
    }

    private func handle(_ event: NSEvent) {
        guard !expanding else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) { matcher.reset(); return }
        switch Int(event.keyCode) {
        case kVK_Delete:
            matcher.deleteBackward(); return
        case kVK_Return, kVK_Tab, kVK_Escape, kVK_LeftArrow, kVK_RightArrow,
             kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown, kVK_ForwardDelete:
            matcher.reset(); return
        default:
            break
        }
        guard let chars = event.characters, !chars.isEmpty else { return }
        let clips = ClipboardStore.shared.abbreviatedClips
        guard let match = matcher.type(chars, abbreviations: clips.compactMap(\.abbreviation)),
              let clip = clips.first(where: { $0.abbreviation == match }) else { return }
        expand(clip, replacing: match.count)
    }

    private func expand(_ clip: ClipItem, replacing count: Int) {
        expanding = true
        let saved = PasteService.snapshotPasteboard()
        Self.post(keyCode: CGKeyCode(kVK_Delete), times: count)
        let monitor = AppController.shared.monitor
        // Give the app a moment to apply the backspaces before pasting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            monitor.suppressUntilChangeCount = PasteService.copy(clip)
            PasteService.sendCommandV()
            // Restore what was on the clipboard once the paste has been read.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                monitor.suppressUntilChangeCount = PasteService.restorePasteboard(saved)
                self.expanding = false
            }
        }
    }

    private static func post(keyCode: CGKeyCode, times: Int) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<times {
            CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
        }
    }
}
#endif
