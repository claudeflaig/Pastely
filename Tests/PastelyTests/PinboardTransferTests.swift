import AppKit
import XCTest
@testable import Pastely

/// Export on one Mac, import on another: each store lives in a folder of its
/// own, so the test never touches the real history.
@MainActor
final class PinboardTransferTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PinboardTransferTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func pngData(_ color: NSColor) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 3, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 3).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    private func imageFiles(in store: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: store.appendingPathComponent("images").path)
    }

    func testExportThenImportRestoresPinboardsWithoutDuplicates() throws {
        // The old Mac: a folder with a pinboard of text, rich text, a color
        // and a file, and a pinboard with an image.
        let oldMac = ClipboardStore(baseDirectory: root.appendingPathComponent("old"))
        let work = oldMac.addGroup(name: "Arbeit")
        let templates = oldMac.addPinboard(name: "Vorlagen", colorHex: "#FF5F57")
        oldMac.movePinboard(templates.id, into: work.id)
        let images = oldMac.addPinboard(name: "Bilder", colorHex: "#28C840")
        let png = pngData(.systemOrange)

        let clips: [ClipItem] = [
            ClipItem(type: .text, text: "Liebe Grüsse", customTitle: "Gruss", abbreviation: ";lg"),
            ClipItem(type: .richText, text: "Fett", rtfData: Data("{\\rtf1 \\b Fett}".utf8)),
            ClipItem(type: .color, text: "#5B8DEF", colorHex: "#5B8DEF"),
            ClipItem(type: .file, fileURLs: ["file:///Users/someone/Documents/Vertrag.pdf"]),
        ]
        for clip in clips.reversed() {
            XCTAssertTrue(oldMac.insertImportedClip(clip, imageData: nil, into: templates.id))
        }
        XCTAssertTrue(oldMac.insertImportedClip(ClipItem(type: .image, customTitle: "Logo"),
                                                imageData: png, into: images.id))

        let file = root.appendingPathComponent("Pastely Pinboards.json")
        try oldMac.pinboardArchive().encoded().write(to: file)

        // The new Mac already has a "vorlagen" board holding one of the clips
        // and one of its own.
        let newDir = root.appendingPathComponent("new")
        let newMac = ClipboardStore(baseDirectory: newDir)
        let own = newMac.addPinboard(name: "vorlagen", colorHex: "#2F80ED")
        newMac.insertImportedClip(ClipItem(type: .text, text: "Eigener Text"), imageData: nil, into: own.id)
        newMac.insertImportedClip(ClipItem(type: .text, text: "Liebe Grüsse"), imageData: nil, into: own.id)

        let archive = try PinboardArchive.decode(Data(contentsOf: file))
        XCTAssertNotNil(archive.exportedAt)
        let result = newMac.importPinboards(archive)
        XCTAssertEqual(result, .init(clipsAdded: 4, clipsSkipped: 1, boardsCreated: 1, boardsMerged: 1))
        newMac.saveNow()

        // What the new Mac reads back from disk.
        let reopened = ClipboardStore(baseDirectory: newDir)
        XCTAssertEqual(reopened.pinboards.map(\.name), ["vorlagen", "Bilder"])

        let merged = reopened.pinboards[0]
        XCTAssertEqual(merged.colorHex, "#2F80ED", "an existing board keeps its color")
        XCTAssertNil(merged.groupID, "an existing board stays where it is")
        XCTAssertEqual(merged.items.map(\.type), [.richText, .color, .file, .text, .text])
        XCTAssertEqual(merged.items.map(\.displayTitle),
                       ["Fett", "#5B8DEF", "Vertrag.pdf", "Liebe Grüsse", "Eigener Text"])
        XCTAssertEqual(merged.items[0].rtfData, clips[1].rtfData)
        XCTAssertEqual(merged.items[2].fileURLs, clips[3].fileURLs)

        let pictures = reopened.pinboards[1]
        XCTAssertEqual(pictures.colorHex, "#28C840")
        XCTAssertEqual(pictures.items.count, 1)
        XCTAssertEqual(pictures.items[0].customTitle, "Logo")
        let imageURL = try XCTUnwrap(reopened.imageURL(for: pictures.items[0]))
        XCTAssertEqual(try Data(contentsOf: imageURL), png)

        // The export remembers each board's folder.
        let oldMacTemplates = try PinboardArchive.decode(Data(contentsOf: file)).pinboards[0]
        XCTAssertEqual(oldMacTemplates.folder, "Arbeit")

        // Importing the same file again adds nothing, not even image files.
        let filesBefore = try imageFiles(in: newDir)
        let again = reopened.importPinboards(archive)
        XCTAssertEqual(again.clipsAdded, 0)
        XCTAssertEqual(again.clipsSkipped, 5)
        XCTAssertEqual(again.boardsCreated, 0)
        XCTAssertEqual(try imageFiles(in: newDir).sorted(), filesBefore.sorted())
        XCTAssertEqual(reopened.pinboards.map(\.items.count), [5, 1])
    }

    func testNewBoardReturnsToItsFolder() throws {
        let archive = PinboardArchive(pinboards: [
            .init(name: "Mails", colorHex: "#A259FF", folder: "Arbeit",
                  items: [.init(type: "text", text: "Hallo")]),
            .init(name: "Code", folder: "arbeit", items: []),
        ])
        let store = ClipboardStore(baseDirectory: root.appendingPathComponent("folders"))
        store.importPinboards(try PinboardArchive.decode(archive.encoded()))
        XCTAssertEqual(store.groups.map(\.name), ["Arbeit"], "folders match by name, ignoring case")
        XCTAssertEqual(store.pinboards.map { store.group(of: $0)?.name }, ["Arbeit", "Arbeit"])
    }

    func testOlderExportWithoutFolderStillImports() throws {
        let json = #"{"format":"pastely.pinboards","version":1,"pinboards":[{"name":"Alt","items":[{"type":"text","text":"x"}]}]}"#
        let store = ClipboardStore(baseDirectory: root.appendingPathComponent("legacy"))
        let result = store.importPinboards(try PinboardArchive.decode(Data(json.utf8)))
        XCTAssertEqual(result.clipsAdded, 1)
        XCTAssertTrue(store.groups.isEmpty)
    }
}
