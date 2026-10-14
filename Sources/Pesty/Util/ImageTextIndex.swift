import AppKit
import CryptoKit
import Vision

/// Text recognized in image clips and screenshots, so search finds a capture
/// by what it shows, as Paste's OCR search does. Recognition runs once per
/// image on device, in the background, and the result is kept on disk.
@MainActor
enum ImageTextIndex {
    private static var texts: [String: String] = load()
    private static var pending: Set<String> = []
    private static var saveScheduled = false

    private static var fileURL: URL {
        ClipboardStore.localBase.appendingPathComponent("image-text.json")
    }

    /// Lowercased recognized text, or nil while the image is not indexed yet.
    static func text(for item: ClipItem) -> String? {
        guard let key = key(for: item) else { return nil }
        return texts[key]
    }

    /// Queues every image among `items` that has not been read yet.
    static func index(_ items: [ClipItem]) {
        for item in items {
            guard let key = key(for: item), texts[key] == nil, !pending.contains(key),
                  let url = imageURL(for: item) else { continue }
            pending.insert(key)
            Task.detached(priority: .utility) {
                let text = recognize(url) ?? ""
                await MainActor.run {
                    pending.remove(key)
                    texts[key] = text.lowercased()
                    scheduleSave()
                }
            }
        }
    }

    private static func imageURL(for item: ClipItem) -> URL? {
        if item.type == .image { return ClipboardStore.shared.imageURL(for: item) }
        return ClipPreviewProvider.imageFileURL(for: item)
    }

    /// Keyed by the image itself, so a clip copied into a pinboard or synced
    /// in shares the result with its original.
    private static func key(for item: ClipItem) -> String? {
        if item.type == .image { return item.imageHash ?? item.imageFileName }
        guard let url = ClipPreviewProvider.imageFileURL(for: item) else { return nil }
        return SHA256.hash(data: Data(url.path.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func recognize(_ url: URL) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(url: url)
        guard (try? handler.perform([request])) != nil else { return nil }
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    /// Batches writes while a backlog of screenshots is being read.
    private static func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveScheduled = false
            if let data = try? JSONEncoder().encode(texts) {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
}
