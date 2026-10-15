import AppKit
import Vision

#if !MAS
/// Copies the text in a part of the screen, as TextSniper does: the user drags
/// a box with the system's own screenshot crosshair, the box is read on device
/// and the text lands on the clipboard, where the monitor picks it up as a clip.
@MainActor
enum ScreenTextCapture {
    private static var isCapturing = false

    /// `screencapture` asks for the Screen Recording permission itself and
    /// gives Esc, Space for a window and the usual crosshair for free.
    static func start(onResult: @escaping @MainActor (Result) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("pastely-text-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i: select interactively, -x: no shutter sound, -o: no window shadow.
        process.arguments = ["-i", "-x", "-o", file.path]
        process.terminationHandler = { _ in
            Task.detached(priority: .userInitiated) {
                let text = FileManager.default.fileExists(atPath: file.path) ? recognize(file) : nil
                try? FileManager.default.removeItem(at: file)
                await MainActor.run {
                    isCapturing = false
                    switch text {
                    case nil: return  // Cancelled with Esc.
                    case let text?:
                        guard !text.isEmpty else { onResult(.noText); return }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        onResult(.copied(text))
                    }
                }
            }
        }
        do {
            try process.run()
        } catch {
            isCapturing = false
        }
    }

    enum Result {
        case copied(String)
        case noText
    }

    /// Keeps the lines as they appear, so a list or an address stays readable.
    nonisolated private static func recognize(_ url: URL) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(url: url)
        guard (try? handler.perform([request])) != nil else { return "" }
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
#endif
