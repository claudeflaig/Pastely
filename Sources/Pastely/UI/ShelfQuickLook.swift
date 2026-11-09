import AppKit
import QuickLookUI

/// Quick Look for the Shelf's files: Space opens the selected one, and the
/// arrow keys in the preview move through the rest of the Shelf.
@MainActor
final class ShelfQuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = ShelfQuickLook()

    private var urls: [URL] = []
    /// Told which file the preview showed last when it closes.
    private var onClose: ((Int) -> Void)?
    /// The app that was in front before the preview, which gets the focus
    /// back afterwards: clicking the Shelf never takes it away.
    private var previousApp: NSRunningApplication?

    /// Whether the preview shows the Shelf's files, not another part of the
    /// app's (Screeny's in the suite).
    var isShown: Bool {
        guard onClose != nil, QLPreviewPanel.sharedPreviewPanelExists(),
              let panel = QLPreviewPanel.shared() else { return false }
        return panel.isVisible && panel.dataSource === self
    }

    var hasFiles: Bool { !urls.isEmpty }

    /// What Quick Look can show for an item: its files on disk, or for a
    /// picture or text without one a copy written to a temporary file.
    static func previewURLs(for item: ClipItem) -> [URL] {
        let fm = FileManager.default
        let onDisk = ShelfModel.fileURLs(of: [item]).filter { fm.fileExists(atPath: $0.path) }
        if !onDisk.isEmpty { return onDisk }
        let name = ShelfTextFile.fileName(for: ShelfItemText.name(of: item), fallback: "Clip")
        switch item.type {
        case .image:
            guard let image = ClipboardStore.shared.loadImage(for: item),
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else { return [] }
            return tempFile(named: "\(item.id.uuidString.prefix(8)) Image.png", data: png)
        case .richText:
            if let rtf = item.rtfData {
                return tempFile(named: "\(name).rtf", data: rtf)
            }
            return tempFile(named: "\(name).txt", data: Data((item.text ?? "").utf8))
        case .text:
            return tempFile(named: "\(name).txt", data: Data((item.text ?? "").utf8))
        case .file, .link, .color:
            return []
        }
    }

    private static func tempFile(named name: String, data: Data) -> [URL] {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pastely Quick Look", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic) } catch { return [] }
        return [url]
    }

    /// Called while the Shelf is the key window, which then takes control
    /// of the preview through `beginControl`.
    func show(_ urls: [URL], at index: Int, onClose: @escaping (Int) -> Void) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        if !NSApp.isActive {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        self.urls = urls
        self.onClose = onClose
        startIndex = min(max(index, 0), urls.count - 1)
        // The preview opens in front and plays videos only once the app is.
        NSApp.activate()
        if panel.dataSource === self {
            panel.reloadData()
            panel.currentPreviewItemIndex = startIndex
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private var startIndex = 0

    func beginControl(_ panel: QLPreviewPanel) {
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = startIndex
    }

    func endControl(_ panel: QLPreviewPanel) {
        finish(panel)
        if panel.dataSource === self { panel.dataSource = nil }
        if panel.delegate === self { panel.delegate = nil }
    }

    func dismiss() {
        guard isShown, let panel = QLPreviewPanel.shared() else { return }
        panel.orderOut(nil)
        finish(panel)
    }

    /// The preview closed itself, from its close button or Escape.
    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? QLPreviewPanel else { return }
        finish(panel)
    }

    private func finish(_ panel: QLPreviewPanel) {
        guard let onClose else { return }
        let index = panel.currentPreviewItemIndex
        self.onClose = nil
        urls = []
        if let previousApp, previousApp != NSRunningApplication.current {
            previousApp.activate()
        }
        previousApp = nil
        onClose(index)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated {
            urls.indices.contains(index) ? urls[index] as NSURL : nil
        }
    }
}
