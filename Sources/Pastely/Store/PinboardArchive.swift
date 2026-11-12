import AppKit

/// Pinboards as a portable JSON file, for backups, for moving them to another
/// Mac and for bringing templates over from another clipboard manager.
/// Images travel inline as PNG data so the file stands on its own; file clips
/// keep only their paths, since Pastely never copies the files themselves.
struct PinboardArchive: Codable, Equatable {
    struct Board: Codable, Equatable {
        var name: String
        var colorHex: String?
        /// The pinboard folder the board sat in; missing in older exports.
        var folder: String?
        var items: [Item]
    }

    struct Item: Codable, Equatable {
        var type: String
        var title: String?
        var text: String?
        var colorHex: String?
        var fileURLs: [String]?
        var imagePNG: Data?
        var rtf: Data?
        var html: Data?
        var sourceBundleID: String?
        var sourceAppName: String?
        var createdAt: Date?
        var abbreviation: String?
    }

    var format = "pastely.pinboards"
    var version = 1
    var pinboards: [Board]
    /// When and on which Mac the file was written; missing in older exports.
    var exportedAt: Date?
    var computer: String?

    /// What an import did, for the message shown afterwards.
    struct ImportResult: Equatable {
        var clipsAdded = 0
        var clipsSkipped = 0
        var boardsCreated = 0
        var boardsMerged = 0
    }

    static func decode(_ data: Data) throws -> PinboardArchive {
        let archive = try JSONDecoder().decode(PinboardArchive.self, from: data)
        guard archive.format == "pastely.pinboards" else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return archive
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The clip an archived item becomes; images need the store to keep their
    /// file, so they are handed back as data alongside.
    static func clip(from item: Item) -> (ClipItem, image: Data?)? {
        let type = ClipType(rawValue: item.type) ?? (item.text != nil ? .text : nil)
        guard let type else { return nil }
        let clip = ClipItem(type: type,
                            text: item.text,
                            rtfData: item.rtf,
                            htmlData: item.html,
                            fileURLs: item.fileURLs ?? [],
                            colorHex: item.colorHex,
                            sourceBundleID: item.sourceBundleID,
                            sourceAppName: item.sourceAppName,
                            customTitle: item.title,
                            abbreviation: item.abbreviation,
                            createdAt: item.createdAt ?? Date())
        return (clip.recognizingHexColor(), item.imagePNG)
    }
}

@MainActor
extension ClipboardStore {
    func pinboardArchive() -> PinboardArchive {
        PinboardArchive(pinboards: pinboards.map { board in
            PinboardArchive.Board(
                name: board.name,
                colorHex: board.colorHex,
                folder: group(of: board)?.name,
                items: board.items.map { item in
                    var png: Data?
                    if item.type == .image, let url = imageURL(for: item) {
                        png = try? Data(contentsOf: url)
                    }
                    return PinboardArchive.Item(type: item.type.rawValue,
                                                title: item.customTitle,
                                                text: item.text,
                                                colorHex: item.colorHex,
                                                fileURLs: item.fileURLs.isEmpty ? nil : item.fileURLs,
                                                imagePNG: png,
                                                rtf: item.rtfData,
                                                html: item.htmlData,
                                                sourceBundleID: item.sourceBundleID,
                                                sourceAppName: item.sourceAppName,
                                                createdAt: item.createdAt,
                                                abbreviation: item.abbreviation)
                })
        },
        exportedAt: Date(),
        computer: Host.current().localizedName)
    }

    /// Adds the archive's boards without touching what is already here:
    /// a board merges into the board of the same name, a clip that board
    /// already holds is skipped, so importing the same file twice adds
    /// nothing. New boards go back into their folder, created if needed.
    @discardableResult
    func importPinboards(_ archive: PinboardArchive) -> PinboardArchive.ImportResult {
        var result = PinboardArchive.ImportResult()
        for board in archive.pinboards {
            let id: UUID
            if let existing = pinboards.first(where: { $0.name.caseInsensitiveCompare(board.name) == .orderedSame }) {
                id = existing.id
                result.boardsMerged += 1
            } else {
                id = addPinboard(name: board.name, colorHex: board.colorHex).id
                result.boardsCreated += 1
                if let folder = board.folder?.trimmingCharacters(in: .whitespaces), !folder.isEmpty {
                    let group = groups.first { $0.name.caseInsensitiveCompare(folder) == .orderedSame }
                        ?? addGroup(name: folder)
                    movePinboard(id, into: group.id)
                }
            }
            // Each clip goes in front, so walk backwards to keep the
            // archive's order.
            for archived in board.items.reversed() {
                guard let (clip, image) = PinboardArchive.clip(from: archived) else { continue }
                if insertImportedClip(clip, imageData: image, into: id) {
                    result.clipsAdded += 1
                } else {
                    result.clipsSkipped += 1
                }
            }
        }
        return result
    }
}
