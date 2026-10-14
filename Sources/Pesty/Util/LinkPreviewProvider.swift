import AppKit
import CryptoKit
import ImageIO
import LinkPresentation

/// The page title and preview image a link card shows, the way Paste renders
/// links. Fetched once per URL with LinkPresentation and kept on disk, so a
/// card never goes back to the network after the first successful load.
struct LinkPreview {
    let title: String?
    let image: NSImage?
}

@MainActor
enum LinkPreviewProvider {
    nonisolated private static let maxImagePixels = 900
    private static let fetchTimeout: TimeInterval = 10

    private static var memory: [URL: LinkPreview] = [:]
    /// URLs whose fetch failed this launch, so scrolling past a dead link does
    /// not refetch it on every appearance.
    private static var failed: Set<URL> = []
    private static var inFlight: [URL: Task<LinkPreview?, Never>] = [:]

    private static var directory: URL {
        ClipboardStore.localBase.appendingPathComponent("link-previews", isDirectory: true)
    }

    /// Only plain web links get a preview; anything else keeps the compass.
    static func url(for item: ClipItem) -> URL? {
        guard item.type == .link,
              let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    static func cached(for url: URL) -> LinkPreview? {
        if let hit = memory[url] { return hit }
        guard let loaded = readDisk(for: url) else { return nil }
        memory[url] = loaded
        return loaded
    }

    static func preview(for url: URL) async -> LinkPreview? {
        if let hit = cached(for: url) { return hit }
        guard !failed.contains(url) else { return nil }
        if let running = inFlight[url] { return await running.value }
        let task = Task { await fetch(url) }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result {
            memory[url] = result
            writeDisk(result, for: url)
        } else {
            failed.insert(url)
        }
        return result
    }

    private static func fetch(_ url: URL) async -> LinkPreview? {
        let provider = LPMetadataProvider()
        provider.timeout = fetchTimeout
        provider.shouldFetchSubresources = true
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
        var image = await loadImage(metadata.imageProvider)
        if image == nil { image = await loadImage(metadata.iconProvider) }
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard image != nil || !(title ?? "").isEmpty else { return nil }
        return LinkPreview(title: title, image: image)
    }

    private static func loadImage(_ provider: NSItemProvider?) async -> NSImage? {
        guard let provider, provider.canLoadObject(ofClass: NSImage.self) else { return nil }
        let data: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                // NSImage is not Sendable, so it crosses back as PNG data.
                let image = object as? NSImage
                continuation.resume(returning: image.flatMap(downsampledPNG))
            }
        }
        return data.flatMap(NSImage.init(data:))
    }

    /// Keeps a large hero image from costing megabytes per card.
    nonisolated private static func downsampledPNG(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let source = CGImageSourceCreateWithData(tiff as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxImagePixels,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    // MARK: Disk cache

    private struct Record: Codable {
        let title: String?
        let hasImage: Bool
    }

    private static func key(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8))
            .prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func readDisk(for url: URL) -> LinkPreview? {
        let base = directory.appendingPathComponent(key(for: url))
        guard let data = try? Data(contentsOf: base.appendingPathExtension("json")),
              let record = try? JSONDecoder().decode(Record.self, from: data) else { return nil }
        let image = record.hasImage ? NSImage(contentsOf: base.appendingPathExtension("png")) : nil
        return LinkPreview(title: record.title, image: image)
    }

    private static func writeDisk(_ preview: LinkPreview, for url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = directory.appendingPathComponent(key(for: url))
        var hasImage = false
        if let image = preview.image,
           let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            hasImage = (try? png.write(to: base.appendingPathExtension("png"), options: .atomic)) != nil
        }
        let record = Record(title: preview.title, hasImage: hasImage)
        if let data = try? JSONEncoder().encode(record) {
            try? data.write(to: base.appendingPathExtension("json"), options: .atomic)
        }
    }
}
