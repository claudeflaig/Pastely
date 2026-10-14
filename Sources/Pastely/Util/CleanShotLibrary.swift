import AppKit
import CryptoKit
import Observation

/// Tells a screenshot apart from any other picture by its file name, which is
/// all a copied file carries: macOS, CleanShot and the common capture tools
/// name their files consistently.
enum ScreenshotDetector {
    private static let prefixes = ["cleanshot", "screenshot", "bildschirmfoto", "screen shot",
                                   "capture d’écran", "captura de pantalla", "schermata"]

    static func isScreenshot(_ url: URL) -> Bool {
        if url.path.contains("/CleanShot/media/") { return true }
        let name = url.lastPathComponent.lowercased()
        return prefixes.contains { name.hasPrefix($0) }
    }
}

/// CleanShot X's capture history, shown as a read-only pinboard. CleanShot
/// keeps every capture in its own folder and records the app each one was
/// taken in, so the cards get that app's color and icon like copied clips do.
@Observable
@MainActor
final class CleanShotLibrary {
    static let shared = CleanShotLibrary()

    static let bundleID = "pl.maketheweb.cleanshotx"

    private(set) var items: [ClipItem] = []

    /// The sandboxed App Store build cannot read another app's files.
    var isAvailable: Bool {
        #if MAS
        return false
        #else
        return Settings.shared.showCleanShotHistory
            && FileManager.default.fileExists(atPath: Self.mediaDirectory.path)
        #endif
    }

    private static var mediaDirectory: URL {
        let home = getpwuid(getuid()).map { URL(fileURLWithPath: String(cString: $0.pointee.pw_dir)) }
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return home.appendingPathComponent("Library/Application Support/CleanShot/media", isDirectory: true)
    }

    private struct HistoryEntry: Decodable {
        struct AppMetadata: Decodable {
            let bundleID: String?
            let app: String?
        }
        let url: String?
        let creationDate: Double?
        let appMetadata: AppMetadata?
    }

    func refresh() {
        guard isAvailable else {
            if !items.isEmpty { items = [] }
            return
        }
        let fresh = Self.fromHistory() ?? Self.fromFolder()
        if fresh != items { items = fresh }
    }

    /// CleanShot's own record, newest first, which also names the source app.
    private static func fromHistory() -> [ClipItem]? {
        guard let json = UserDefaults(suiteName: bundleID)?.data(forKey: "mediaHistory"),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: json)
        else { return nil }
        let fm = FileManager.default
        let items = entries.compactMap { entry -> ClipItem? in
            guard let string = entry.url, let url = URL(string: string), url.isFileURL,
                  fm.fileExists(atPath: url.path) else { return nil }
            let date = entry.creationDate.map(Date.init(timeIntervalSinceReferenceDate:))
            return item(for: url, date: date ?? modificationDate(url),
                        bundleID: entry.appMetadata?.bundleID, appName: entry.appMetadata?.app)
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    /// Without a readable record, the capture folders themselves.
    private static func fromFolder() -> [ClipItem] {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: mediaDirectory, includingPropertiesForKeys: nil)
        else { return [] }
        let files = folders.flatMap { folder in
            (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: .skipsHiddenFiles)) ?? []
        }
        return files
            .map { item(for: $0, date: modificationDate($0), bundleID: nil, appName: nil) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func item(for url: URL, date: Date, bundleID: String?, appName: String?) -> ClipItem {
        ClipItem(id: stableID(for: url),
                 type: .file,
                 text: url.lastPathComponent,
                 fileURLs: [url.absoluteString],
                 sourceBundleID: bundleID ?? Self.bundleID,
                 sourceAppName: appName ?? "CleanShot X",
                 createdAt: date)
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// The same capture keeps its identity across refreshes, so the selection
    /// survives a reload.
    static func stableID(for url: URL) -> UUID {
        var bytes = Array(Insecure.MD5.hash(data: Data(url.path.utf8)))
        bytes[6] = (bytes[6] & 0x0F) | 0x30
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
