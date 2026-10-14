import AppKit
import Observation
import SwiftUI

/// Small cards in the screen's corner for each new clip and each file that
/// lands in a folder tab, as Dropover shows them: drag one straight into an
/// app, double-click to open it, or let it fade after a few seconds.
@MainActor
final class ThumbnailShelf {
    static let shared = ThumbnailShelf()

    private let model = ShelfModel()
    private var panel: NSPanel?
    private var host: NSHostingView<ShelfView>?

    /// How many cards stay on screen at once; older ones make room.
    private static let maxCards = 3

    private init() {
        model.onChange = { [weak self] in self?.layout() }
    }

    func show(_ item: ClipItem) {
        guard Settings.shared.showThumbnails, !AppController.shared.isBarPresented else { return }
        model.add(item, keeping: Self.maxCards)
    }

    private func layout() {
        guard !model.entries.isEmpty else {
            panel?.orderOut(nil)
            return
        }
        let panel = self.panel ?? makePanel()
        guard let host,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main else { return }
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let visible = screen.visibleFrame
        panel.setFrame(NSRect(x: visible.maxX - size.width - 12, y: visible.minY + 12,
                              width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let host = NSHostingView(rootView: ShelfView(model: model))
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 180, height: 160),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.sharingType = Settings.shared.hideWhileScreenSharing ? .none : .readOnly
        panel.contentView = host
        self.panel = panel
        self.host = host
        return panel
    }
}

@Observable
@MainActor
final class ShelfModel {
    struct Entry: Identifiable {
        let id = UUID()
        let item: ClipItem
        var remaining: TimeInterval
    }

    private(set) var entries: [Entry] = []
    /// While the pointer is on the shelf, nothing fades.
    var hovering = false
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var timer: Timer?

    private static let lifetime: TimeInterval = 6
    private static let tick: TimeInterval = 0.25

    func add(_ item: ClipItem, keeping limit: Int) {
        // The same file or clip again replaces its card instead of stacking.
        entries.removeAll { $0.item.id == item.id }
        entries.append(Entry(item: item, remaining: Self.lifetime))
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
        startTimer()
        onChange?()
    }

    func remove(_ id: Entry.ID) {
        entries.removeAll { $0.id == id }
        onChange?()
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    private func step() {
        guard !hovering else { return }
        for i in entries.indices { entries[i].remaining -= Self.tick }
        let before = entries.count
        entries.removeAll { $0.remaining <= 0 }
        if entries.isEmpty { timer?.invalidate(); timer = nil }
        if entries.count != before { onChange?() }
    }
}

struct ShelfView: View {
    let model: ShelfModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(model.entries) { entry in
                ShelfCard(item: entry.item) { model.remove(entry.id) }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(14)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.entries.map(\.id))
        .onHover { model.hovering = $0 }
    }
}

/// A bar card at half size. The card itself takes no clicks; the shelf
/// handles drag, double-click and close on top of it.
private struct ShelfCard: View {
    let item: ClipItem
    let close: () -> Void
    @State private var hovering = false

    private static let scale: CGFloat = 0.5
    private static let cardHeight: CGFloat = 250

    var body: some View {
        ClipCardView(item: item, index: 0, selected: false)
            .frame(width: Theme.cardWidth, height: Self.cardHeight)
            .allowsHitTesting(false)
            .scaleEffect(Self.scale)
            .frame(width: Theme.cardWidth * Self.scale, height: Self.cardHeight * Self.scale)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(count: 2) { open() }
            .onDrag { ClipDragProvider.make(for: item) }
            .overlay(alignment: .topLeading) {
                if hovering {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .regular))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .offset(x: -6, y: -6)
                    .help("Dismiss")
                }
            }
            .help("Drag into any app, or double-click to open")
    }

    /// A file opens in its app; a clip opens the bar on it.
    private func open() {
        if item.type == .file, let url = item.fileURLs.first.flatMap(URL.init(string:)), url.isFileURL {
            NSWorkspace.shared.open(url)
        } else {
            AppController.shared.showBar()
        }
        close()
    }
}
