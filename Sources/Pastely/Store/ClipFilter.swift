import Foundation
import UniformTypeIdentifiers

/// The kinds a search can be narrowed to, as Paste's filter chips name them.
/// They are coarser than `ClipType`: rich text counts as text, and a picture
/// is either a screenshot or an image whether it was copied as pixels or as a
/// file.
enum ClipKind: String, CaseIterable, Identifiable {
    case text
    case link
    case image
    case screenshot
    case file
    case color

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        case .screenshot: "Screenshot"
        case .file: "File"
        case .color: "Color"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .screenshot: "camera.viewfinder"
        case .file: "doc"
        case .color: "paintpalette"
        }
    }

    static func of(_ item: ClipItem) -> ClipKind {
        switch item.type {
        case .text, .richText: return .text
        case .link: return .link
        case .color: return .color
        case .image: return .image
        case .file:
            guard item.fileURLs.count == 1,
                  let url = item.fileURLs.first.flatMap(URL.init(string:)), url.isFileURL,
                  let type = UTType(filenameExtension: url.pathExtension),
                  type.conforms(to: .image) else { return .file }
            return ScreenshotDetector.isScreenshot(url) ? .screenshot : .image
        }
    }
}

/// How far back a search reaches.
enum ClipDateRange: String, CaseIterable, Identifiable {
    case today
    case lastWeek
    case lastMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .lastWeek: "Last 7 Days"
        case .lastMonth: "Last 30 Days"
        }
    }

    /// The earliest moment still inside the range.
    func start(relativeTo now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .today: calendar.startOfDay(for: now)
        case .lastWeek: now.addingTimeInterval(-7 * 86_400)
        case .lastMonth: now.addingTimeInterval(-30 * 86_400)
        }
    }
}

/// The filter chips in the bar's search field. Each dimension narrows the
/// result on its own, and they combine with the typed query, including text
/// recognized in images.
struct ClipFilter: Equatable {
    var kinds: Set<ClipKind> = []
    var appBundleID: String?
    /// Shown on the chip; the bundle ID alone means nothing to a person.
    var appName: String?
    var dateRange: ClipDateRange?

    var isActive: Bool { !kinds.isEmpty || appBundleID != nil || dateRange != nil }

    func matches(_ item: ClipItem, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        if !kinds.isEmpty, !kinds.contains(ClipKind.of(item)) { return false }
        if let appBundleID, item.sourceBundleID != appBundleID { return false }
        if let dateRange, item.createdAt < dateRange.start(relativeTo: now, calendar: calendar) { return false }
        return true
    }

    /// The source apps among `items`, most frequent first, for the app menu.
    static func apps(in items: [ClipItem], limit: Int = 12) -> [(bundleID: String, name: String)] {
        var counts: [String: (name: String, count: Int)] = [:]
        for item in items {
            guard let id = item.sourceBundleID, !id.isEmpty else { continue }
            let name = item.sourceAppName ?? id
            counts[id, default: (name, 0)].count += 1
        }
        return counts
            .sorted { $0.value.count != $1.value.count ? $0.value.count > $1.value.count
                                                        : $0.value.name < $1.value.name }
            .prefix(limit)
            .map { ($0.key, $0.value.name) }
    }
}
