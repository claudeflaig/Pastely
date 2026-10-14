import Foundation

/// The ordered clips of a Paste Stack, kept in the order they were copied.
/// `next` is the clip the following ⌘V pastes: the oldest one, or the newest
/// when the order is reversed.
struct PasteStackQueue: Equatable {
    private(set) var items: [ClipItem] = []
    var reversed = false

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }

    /// The clips in the order they will be pasted.
    var pasteOrder: [ClipItem] { reversed ? items.reversed() : items }

    var next: ClipItem? { reversed ? items.last : items.first }

    /// Copying something already on the stack moves it to the end instead of
    /// adding it twice.
    mutating func add(_ item: ClipItem) {
        items.removeAll { $0.id == item.id || $0.sameContent(as: item) }
        items.append(item)
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Takes the clip that was just pasted off the stack.
    @discardableResult
    mutating func popNext() -> ClipItem? {
        guard !items.isEmpty else { return nil }
        return reversed ? items.removeLast() : items.removeFirst()
    }

    mutating func clear() { items.removeAll() }
}
