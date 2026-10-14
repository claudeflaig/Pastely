import Foundation

/// The order of the bar's tabs after Clipboard: pinboards, CleanShot and
/// folders mixed however they were dragged. Stored as keys, so a tab that
/// comes back (CleanShot reinstalled, a folder re-added) finds its place.
enum TabOrder {
    static func key(_ source: BarSource) -> String? {
        switch source {
        case .history: nil
        case .pinboard(let id): "board:\(id.uuidString)"
        case .cleanShot: "cleanshot"
        case .folder(let path): "folder:\(path)"
        case .group(let id): "group:\(id.uuidString)"
        }
    }

    /// `sources` in their stored order. Tabs not stored yet keep their
    /// default order and follow the stored ones, so a new pinboard lands at
    /// the end.
    static func sorted(_ sources: [BarSource], by order: [String]) -> [BarSource] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return sources.enumerated()
            .sorted { a, b in
                let ra = key(a.element).flatMap { rank[$0] } ?? order.count + a.offset
                let rb = key(b.element).flatMap { rank[$0] } ?? order.count + b.offset
                return ra < rb
            }
            .map(\.element)
    }

    /// Puts `source` where `target` is, shifting the rest along, so a dragged
    /// tab lands on the spot it was dropped.
    static func moving(_ source: BarSource, onto target: BarSource,
                       in sources: [BarSource]) -> [BarSource] {
        guard source != target,
              let from = sources.firstIndex(of: source),
              let to = sources.firstIndex(of: target) else { return sources }
        var result = sources
        result.insert(result.remove(at: from), at: to)
        return result
    }
}
