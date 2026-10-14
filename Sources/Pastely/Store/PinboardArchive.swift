import AppKit

/// Pinboards as a portable JSON file, for backups and for bringing templates
/// over from another clipboard manager. Images travel inline as PNG data so
/// the file stands on its own.
struct PinboardArchive: Codable, Equatable {
    struct Board: Codable, Equatable {
        var name: String
        var colorHex: String?
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
        })
    }

    /// Adds the archive's boards, merging into boards of the same name and
    /// skipping clips a board already holds. Returns how many clips were added.
    @discardableResult
    func importPinboards(_ archive: PinboardArchive) -> Int {
        var added = 0
        for board in archive.pinboards {
            let id = pinboards.first { $0.name.caseInsensitiveCompare(board.name) == .orderedSame }?.id
                ?? addPinboard(name: board.name, colorHex: board.colorHex).id
            // Inserted newest-first by saveToPinboard, so walk backwards to
            // keep the archive's order.
            for archived in board.items.reversed() {
                guard var (clip, image) = PinboardArchive.clip(from: archived) else { continue }
                if let image {
                    guard let name = storeImageData(image) else { continue }
                    clip.imageFileName = name
                }
                let before = pinboards.first { $0.id == id }?.items.count ?? 0
                saveToPinboard(clip, boardID: id)
                if (pinboards.first { $0.id == id }?.items.count ?? 0) > before { added += 1 }
            }
        }
        return added
    }
}
