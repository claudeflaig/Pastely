import AppKit

/// Brings templates over from Pasty. Pasty keeps its data inside its own
/// sandbox container, which macOS protects: the first read asks the user
/// whether Pastely may access another app's data. The data is copied into
/// Pastely's folder, so it can be converted after that single consent.
@MainActor
enum PastyImporter {
    static let bundleID = "com.heavylightapps.pasty"

    private static var home: URL {
        getpwuid(getuid()).map { URL(fileURLWithPath: String(cString: $0.pointee.pw_dir)) }
            ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    static var containerLibrary: URL {
        home.appendingPathComponent("Library/Containers/\(bundleID)/Data/Library", isDirectory: true)
    }

    static var importFolder: URL {
        ClipboardStore.localBase.appendingPathComponent("Pasty Import", isDirectory: true)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: home.appendingPathComponent("Library/Containers/\(bundleID)").path)
    }

    /// Copies Pasty's stored data and preferences; returns how many files
    /// came across.
    static func copyData() throws -> Int {
        let fm = FileManager.default
        // Fails here, before the previous copy is cleared, when access to
        // Pasty's container has not been granted.
        _ = try fm.contentsOfDirectory(at: containerLibrary, includingPropertiesForKeys: nil)
        try? fm.removeItem(at: importFolder)
        try fm.createDirectory(at: importFolder, withIntermediateDirectories: true)
        var copied = 0
        for name in ["Application Support", "Preferences"] {
            let source = containerLibrary.appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path) else { continue }
            try fm.copyItem(at: source, to: importFolder.appendingPathComponent(name))
            copied += fm.enumerator(at: importFolder.appendingPathComponent(name),
                                    includingPropertiesForKeys: nil)?.allObjects.count ?? 0
        }
        return copied
    }
}

import SQLite3

extension PastyImporter {
    /// Pasty's pinboards ("spaces") from its Core Data store, as an archive
    /// Pastely imports like any other. The History space is left out: only
    /// the clips someone kept on purpose come across.
    static func archive(fromDatabase url: URL) throws -> PinboardArchive {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { sqlite3_close(db) }

        let spaces = try rows(db, """
            SELECT Z_PK, ZNAME, ZCOLOR FROM ZSPACE
            WHERE ZID <> 'general' ORDER BY ZORDER
            """) { stmt in
            (Int(sqlite3_column_int64(stmt, 0)), text(stmt, 1) ?? "Pinboard", text(stmt, 2))
        }

        var boards: [PinboardArchive.Board] = []
        for space in spaces {
            let items = try rows(db, """
                SELECT i.Z_PK, i.ZTITLE, i.ZCREATEDAT, a.ZBUNDLEIDENTIFIER, a.ZNAME
                FROM ZPASTEBOARDITEM i LEFT JOIN ZAPPLICATION a ON a.Z_PK = i.ZAPPLICATION
                WHERE i.ZSPACE = \(space.0) ORDER BY i.ZCREATEDAT DESC
                """) { stmt in
                (Int(sqlite3_column_int64(stmt, 0)), text(stmt, 1),
                 sqlite3_column_double(stmt, 2), text(stmt, 3), text(stmt, 4))
            }
            let archived = try items.compactMap { item -> PinboardArchive.Item? in
                let contents = try rows(db, """
                    SELECT ZTYPE, ZDATA FROM ZPASTEBOARDITEMCONTENT WHERE ZITEM = \(item.0)
                    """) { stmt in (text(stmt, 0) ?? "", blob(stmt, 1)) }
                var byType: [String: Data] = [:]
                for (type, data) in contents { if let data { byType[type] = data } }
                return makeItem(byType, title: item.1, created: item.2, bundleID: item.3, appName: item.4)
            }
            boards.append(.init(name: space.1, colorHex: space.2, items: archived))
        }
        return PinboardArchive(pinboards: boards)
    }

    private static func makeItem(_ byType: [String: Data], title: String?, created: Double,
                                 bundleID: String?, appName: String?) -> PinboardArchive.Item? {
        let text = (byType["public.utf8-plain-text"] ?? byType["public.text"])
            .flatMap { String(data: $0, encoding: .utf8) }
            ?? byType["public.utf16-external-plain-text"].flatMap { String(data: $0, encoding: .utf16) }
        let png = byType["public.png"] ?? byType["public.tiff"].flatMap {
            NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
        }
        let fileURL = byType["public.file-url"].flatMap { String(data: $0, encoding: .utf8) }

        let type: ClipType
        if let fileURL, !fileURL.isEmpty {
            type = .file
        } else if text == nil, png != nil {
            type = .image
        } else if let text {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if byType["public.rtf"] != nil {
                type = .richText
            } else if !trimmed.contains(" "), !trimmed.contains("\n"),
                      let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                type = .link
            } else {
                type = .text
            }
        } else {
            return nil
        }
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PinboardArchive.Item(type: type.rawValue,
                                    title: cleanTitle?.isEmpty == false ? cleanTitle : nil,
                                    text: text,
                                    fileURLs: fileURL.map { [$0] },
                                    imagePNG: type == .image ? png : nil,
                                    rtf: type == .richText ? byType["public.rtf"] : nil,
                                    html: type == .richText ? nil : byType["public.html"],
                                    sourceBundleID: bundleID,
                                    sourceAppName: appName,
                                    createdAt: Date(timeIntervalSinceReferenceDate: created))
    }

    private static func rows<T>(_ db: OpaquePointer?, _ sql: String,
                                _ read: (OpaquePointer?) -> T) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { sqlite3_finalize(stmt) }
        var result: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW { result.append(read(stmt)) }
        return result
    }

    private static func text(_ stmt: OpaquePointer?, _ column: Int32) -> String? {
        sqlite3_column_text(stmt, column).map { String(cString: $0) }
    }

    private static func blob(_ stmt: OpaquePointer?, _ column: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(stmt, column) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, column)))
    }

    /// Copies Pasty's data, then imports its pinboards. Returns the number of
    /// boards and clips brought over.
    static func importPinboards() throws -> (boards: Int, clips: Int) {
        let database = importFolder.appendingPathComponent("Application Support/Pasty/Pasta.sqlite")
        do {
            _ = try copyData()
        } catch where FileManager.default.fileExists(atPath: database.path) {
            // A rebuilt, ad-hoc signed Pastely loses its data-access grant;
            // an earlier copy is still good to import from.
        }
        let archive = try archive(fromDatabase: database)
        let clips = ClipboardStore.shared.importPinboards(archive)
        return (archive.pinboards.count, clips)
    }
}
