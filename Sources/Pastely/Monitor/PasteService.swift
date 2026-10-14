import AppKit
import Carbon.HIToolbox

/// How a clip's content is written to the pasteboard when pasting.
enum PasteFormat {
    /// The clip exactly as captured.
    case original
    /// Text only, all formatting removed.
    case plainText
    /// Bold, italic, underline, and links survive; fonts, sizes, and colors
    /// are normalized away.
    case cleanFormatting
    /// Rich content converted to Markdown text.
    case markdown
}

@MainActor
enum PasteService {
    private static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")
    private static let packagedBundleID = "ch.claudeflaig.pastely"

    private static func markSource(of item: ClipItem, on pasteboard: NSPasteboard) {
        let source = item.sourceBundleID ?? Bundle.main.bundleIdentifier ?? packagedBundleID
        pasteboard.setString(source, forType: sourceType)
    }

    @discardableResult
    static func copy(_ item: ClipItem,
                     format: PasteFormat = .original,
                     to pasteboard: NSPasteboard = .general) -> Int {
        switch format {
        case .plainText:
            if let text = item.plainText {
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                markSource(of: item, on: pasteboard)
                return pasteboard.changeCount
            }
        case .cleanFormatting:
            if let rtf = FormatConverter.cleanedRTF(for: item) {
                pasteboard.clearContents()
                pasteboard.setData(rtf, forType: .rtf)
                if let text = item.plainText { pasteboard.setString(text, forType: .string) }
                markSource(of: item, on: pasteboard)
                return pasteboard.changeCount
            }
            // No rich source to clean: plain text is the honest result.
            if item.plainText != nil {
                return copy(item, format: .plainText, to: pasteboard)
            }
        case .markdown:
            if let markdown = FormatConverter.markdown(for: item) {
                pasteboard.clearContents()
                pasteboard.setString(markdown, forType: .string)
                markSource(of: item, on: pasteboard)
                return pasteboard.changeCount
            }
            if item.plainText != nil {
                return copy(item, format: .plainText, to: pasteboard)
            }
        case .original:
            break
        }
        if item.type == .image {
            guard let img = ClipboardStore.shared.loadImage(for: item) else {
                return pasteboard.changeCount
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([img])
            markSource(of: item, on: pasteboard)
            return pasteboard.changeCount
        }
        pasteboard.clearContents()
        switch item.type {
        case .image:
            break
        case .file:
            let urls = item.fileURLs.compactMap { URL(string: $0) }
            if !urls.isEmpty { pasteboard.writeObjects(urls as [NSURL]) }
            if let t = item.text { pasteboard.setString(t, forType: .string) }
        case .color:
            if let hex = item.colorHex, let c = NSColor(hex: hex) {
                pasteboard.writeObjects([c])
                // A hex code copied as text pastes back exactly as it was typed.
                pasteboard.setString(item.text ?? hex, forType: .string)
            }
        case .richText:
            if let rtf = item.rtfData { pasteboard.setData(rtf, forType: .rtf) }
            if let t = item.text { pasteboard.setString(t, forType: .string) }
        case .text, .link:
            if let t = item.text { pasteboard.setString(t, forType: .string) }
        }
        markSource(of: item, on: pasteboard)
        return pasteboard.changeCount
    }

    static func paste(_ item: ClipItem,
                      into targetApp: NSRunningApplication?,
                      monitor: ClipboardMonitor,
                      format: PasteFormat = .original) {
        let change = copy(item, format: format)
        monitor.suppressUntilChangeCount = change
        if Settings.shared.playSound { NSSound(named: "Pop")?.play() }

        guard let target = targetApp, !target.isTerminated else { return }

        #if MAS
        // Mac App Store (sandboxed) build: copy the clip and return focus to the
        // app the user came from so they can paste with ⌘V. No Accessibility
        // APIs and no synthetic keystrokes are used.
        target.activate()
        #else
        // Direct-download build: optionally paste straight into the active app by
        // synthesizing ⌘V. This requires the user's Accessibility grant.
        guard Settings.shared.pasteDirectly else { return }
        guard AXIsProcessTrusted() else {
            AppController.shared.noteBlockedDirectPaste()
            return
        }
        target.activate()
        waitForFrontmost(target, attempts: 20)
        #endif
    }

    #if !MAS
    private static func waitForFrontmost(_ app: NSRunningApplication, attempts: Int) {
        guard attempts > 0, !app.isTerminated else { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { sendCommandV() }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            waitForFrontmost(app, attempts: attempts - 1)
        }
    }

    static func sendCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Pastes what is on the clipboard now without its formatting, then puts
    /// the original back, so the next ⌘V still pastes it formatted.
    static func pasteClipboardAsPlainText(monitor: ClipboardMonitor) {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else { NSSound.beep(); return }
        guard ensureAccessibility(prompt: true) else { return }
        let saved = snapshotPasteboard()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.suppressUntilChangeCount = pasteboard.changeCount
        sendCommandV()
        // Restore what was on the clipboard once the paste has been read.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            monitor.suppressUntilChangeCount = restorePasteboard(saved)
        }
    }

    static func snapshotPasteboard() -> [[NSPasteboard.PasteboardType: Data]] {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var data: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { data[type] = item.data(forType: type) }
            return data
        }
    }

    static func restorePasteboard(_ items: [[NSPasteboard.PasteboardType: Data]]) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restored = items.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
        return pasteboard.changeCount
    }

    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
    #endif
}
