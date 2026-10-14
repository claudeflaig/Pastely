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

    /// Called with each file that newly lands in a watched folder.
    @ObservationIgnored var onNewFile: ((ClipItem) -> Void)?
    @ObservationIgnored private var watchers: [String: DispatchSourceFileSystemObject] = [:]
    @ObservationIgnored private var known: [String: Set<String>] = [:]
    @ObservationIgnored private var pendingCheck: [String: DispatchWorkItem] = [:]

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
        syncWatchers()
        return added.first
    }

    func remove(_ path: String) {
        Settings.shared.pinnedFolders.removeAll { $0 == path }
        contents[path] = nil
        syncWatchers()
    }

    // MARK: - Watching for new files

    /// Watches every folder tab for files that arrive, such as a finished
    /// download, and reports each one through `onNewFile`.
    func syncWatchers() {
        let wanted = Set(folders)
        for (path, source) in watchers where !wanted.contains(path) {
            source.cancel()
            watchers[path] = nil
            known[path] = nil
        }
        for path in wanted where watchers[path] == nil {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            known[path] = Self.names(in: path)
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .rename, .link], queue: .main)
            source.setEventHandler { [weak self] in self?.scheduleCheck(path) }
            source.setCancelHandler { close(fd) }
            source.resume()
            watchers[path] = source
        }
    }

    /// Waits for a burst of changes to settle: a download is renamed into
    /// place, a copy grows over a moment.
    private func scheduleCheck(_ path: String) {
        pendingCheck[path]?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.checkForNewFiles(path) }
        pendingCheck[path] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func checkForNewFiles(_ path: String) {
        let now = Self.names(in: path)
        let added = now.subtracting(known[path] ?? [])
        known[path] = now
        guard !added.isEmpty else { return }
        refresh(path)
        let arrived = Self.newArrivals(added)
        for item in items(in: path) {
            guard let url = item.fileURLs.first.flatMap(URL.init(string:)),
                  arrived.contains(url.lastPathComponent) else { continue }
            onNewFile?(item)
        }
    }

    private static func names(in path: String) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? [])
    }

    /// The names worth announcing: no hidden files and no downloads still
    /// in progress, which arrive again under their final name when done.
    static func newArrivals(_ names: Set<String>) -> Set<String> {
        let partial: Set<String> = ["download", "crdownload", "part", "partial", "tmp", "opdownload"]
        return names.filter { name in
            !name.hasPrefix(".") && !partial.contains((name as NSString).pathExtension.lowercased())
        }
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
