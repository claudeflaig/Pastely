import AppKit
import UniformTypeIdentifiers

/// Export and import of every pinboard through one JSON file, for moving
/// pinboards to another Mac. Used by Settings and the bar's "…" menu.
@MainActor
enum PinboardTransfer {
    /// Asks where to save and writes the file. Returns what happened, or nil
    /// when the panel was cancelled.
    static func export() -> String? {
        let store = ClipboardStore.shared
        let panel = NSSavePanel()
        let day = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "Pastely Pinboards \(day).json"
        panel.allowedContentTypes = [.json]
        panel.message = "Open this file on your other Mac with Import Pinboards."
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let archive = store.pinboardArchive()
            try archive.encoded().write(to: url, options: .atomic)
            let clips = archive.pinboards.reduce(0) { $0 + $1.items.count }
            return "Exported \(count(archive.pinboards.count, "pinboard")) with \(count(clips, "clip"))."
        } catch {
            return "Export failed: \(error.localizedDescription)"
        }
    }

    /// Asks for an export and merges it in. Returns what happened, or nil
    /// when the panel was cancelled.
    static func importFile() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a file written by Export Pinboards. Existing pinboards are kept."
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let archive: PinboardArchive
        do {
            archive = try PinboardArchive.decode(Data(contentsOf: url))
        } catch {
            return "This file is not a Pastely pinboard export."
        }
        return message(for: ClipboardStore.shared.importPinboards(archive))
    }

    static func message(for result: PinboardArchive.ImportResult) -> String {
        var parts = ["Imported \(count(result.clipsAdded, "clip"))"]
        var boards: [String] = []
        if result.boardsCreated > 0 { boards.append("\(count(result.boardsCreated, "new pinboard"))") }
        if result.boardsMerged > 0 { boards.append("\(result.boardsMerged) merged by name") }
        if !boards.isEmpty { parts[0] += " (\(boards.joined(separator: ", ")))" }
        if result.clipsSkipped > 0 {
            parts.append("\(count(result.clipsSkipped, "clip")) \(result.clipsSkipped == 1 ? "was" : "were") already there")
        }
        return parts.joined(separator: "; ") + "."
    }

    /// From the bar: the bar steps aside for the panel, and the outcome
    /// shows in an alert.
    static func runFromBar(_ action: @escaping @MainActor () -> String?) {
        AppController.shared.hideBar()
        // Let the menu finish closing before a panel takes over.
        DispatchQueue.main.async {
            guard let message = action() else { return }
            let alert = NSAlert()
            alert.messageText = "Pinboards"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            NSApp.activate()
            alert.runModal()
        }
    }

    private static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }
}
