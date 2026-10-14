import AppKit
import Observation

/// Folders shown as read-only pinboards, newest file first, such as
/// Downloads. Each file is a file clip, so it pastes, drags and pins like a
/// copied file, and images and screenshots get their preview.
@Observable
@MainActor
final class FolderLibrary {
    static let shared = FolderLibrary()

    /// How many of a folder's newest entries a pinboard shows.
    private static let limit = 300

    private var contents: [String: [ClipItem]] = [:]

    /// The folders from Settings that exist on this Mac.
    var folders: [String] {
        Settings.shared.pinnedFolders.filter { FileManager.default.fileExists(atPath: $0) }
    }

    func items(in path: String) -> [ClipItem] { contents[path] ?? [] }

    /// Asks for folders and adds each new one as a tab. Returns the first
    /// folder added, so the bar can switch to it.
    @discardableResult
    func chooseAndAdd() -> String? {
        AppController.shared.suppressAutoHide = true
        defer { AppController.shared.suppressAutoHide = false }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Show as Pinboard"
        guard panel.runModal() == .OK else { return nil }
        let added = panel.urls.map(\.path).filter { !Settings.shared.pinnedFolders.contains($0) }
        Settings.shared.pinnedFolders.append(contentsOf: added)
        for path in added { refresh(path) }
        return added.first
    }

    func remove(_ path: String) {
        Settings.shared.pinnedFolders.removeAll { $0 == path }
        contents[path] = nil
    }

    static func title(for path: String) -> String {
        FileManager.default.displayName(atPath: path)
    }

    func refreshAll() {
        for path in folders { refresh(path) }
        contents = contents.filter { folders.contains($0.key) }
    }

    func refresh(_ path: String) {
        let fresh = Self.read(path)
        if fresh != contents[path] { contents[path] = fresh }
    }

    private static func read(_ path: String) -> [ClipItem] {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path), includingPropertiesForKeys: keys, options: .skipsHiddenFiles)
        else { return [] }
        return urls
            .map { url -> (URL, Date) in
                let values = try? url.resourceValues(forKeys: Set(keys))
                // When a file arrived, which is what a Downloads list is about.
                return (url, values?.addedToDirectoryDate ?? values?.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { url, date in
                ClipItem(id: CleanShotLibrary.stableID(for: url),
                         type: .file,
                         text: url.lastPathComponent,
                         fileURLs: [url.absoluteString],
                         sourceBundleID: "com.apple.finder",
                         sourceAppName: "Finder",
                         createdAt: date)
            }
    }
}
