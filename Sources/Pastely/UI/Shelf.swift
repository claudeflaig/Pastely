import AppKit
import Carbon.HIToolbox
import Observation
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

/// A small window that collects new copies and new files from watched
/// folders. It stays until it is closed or emptied: drag
/// the stack out to use everything, or open it to drag items one by one.
/// It can be moved anywhere and opens there again.
@MainActor
final class Shelf {
    static let shared = Shelf()

    let model = ShelfModel()
    private var panel: NSPanel?
    /// Copies on the Shelf, by item, with the pasteboard change that put
    /// them there; only these leave it again once they are pasted.
    private var copies: [UUID: Int] = [:]
    private var keyMonitor: Any?

    // As tall as the Paste Stack; open, the items line up in a row like its cards.
    private static let collapsedSize = NSSize(width: 236, height: 214)
    private static let expandedSize = NSSize(width: 560, height: 214)
    private static let positionKey = "shelfTopLeft"

    private init() {
        model.onChange = { [weak self] in
            self?.layout()
            self?.syncKeyMonitor()
        }
    }

    func add(_ item: ClipItem) {
        model.add(item)
    }

    /// A copy taken off the pasteboard at `change`, so a later ⌘V of it can
    /// take it off the Shelf again.
    func add(_ item: ClipItem, copiedAt change: Int) {
        model.add(item)
        copies[item.id] = change
        syncKeyMonitor()
    }

    /// Pastely pasted `item` itself, from the bar or a menu.
    func notePasted(_ item: ClipItem) {
        guard Settings.shared.shelfRemoveAfterPaste else { return }
        let pasted = model.items.filter { copies[$0.id] != nil && ($0.id == item.id || $0.sameContent(as: item)) }
        guard !pasted.isEmpty else { return }
        model.remove(pasted)
    }

    /// ⌘V in another app pastes what is on the pasteboard, which is a Shelf
    /// copy only while nothing has been copied since.
    private func noteCommandV() {
        guard Settings.shared.shelfRemoveAfterPaste else { return }
        let change = NSPasteboard.general.changeCount
        let pasted = model.items.filter { copies[$0.id] == change }
        guard !pasted.isEmpty else { return }
        // Removed a moment later, once the app has read the pasteboard; the
        // pasteboard itself keeps the copy either way.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.model.remove(pasted)
        }
    }

    /// Listens for ⌘V only while a copy is on the Shelf. A global monitor
    /// needs the Accessibility grant and sees nothing without it.
    private func syncKeyMonitor() {
        copies = copies.filter { id, _ in model.items.contains { $0.id == id } }
        let wanted = !copies.isEmpty && Settings.shared.shelfRemoveAfterPaste
        if wanted, keyMonitor == nil {
            keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard event.keyCode == UInt16(kVK_ANSI_V),
                      flags.contains(.command),
                      !flags.contains(.control),
                      !event.isARepeat else { return }
                MainActor.assumeIsolated { Shelf.shared.noteCommandV() }
            }
        } else if !wanted, let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func clear() { model.clear() }

    /// Back to the lower right corner the next time it opens.
    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.positionKey)
        if !model.items.isEmpty { layout() }
    }

    private func layout() {
        guard !model.items.isEmpty else {
            panel?.orderOut(nil)
            model.expanded = false
            return
        }
        let panel = self.panel ?? makePanel()
        panel.appearance = Settings.shared.barAppearance.nsAppearance
        let size = model.expanded ? Self.expandedSize : Self.collapsedSize
        let topLeft = clampedTopLeft(for: size)
        panel.setFrame(NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height),
                       display: true, animate: panel.isVisible)
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.18; panel.animator().alphaValue = 1 }
        }
    }

    /// Where the shelf was left, kept fully on a screen; the lower right
    /// corner the first time.
    private func clampedTopLeft(for size: NSSize) -> NSPoint {
        let saved = UserDefaults.standard.string(forKey: Self.positionKey).map(NSPointFromString)
        let screen = saved.flatMap { point in NSScreen.screens.first { $0.frame.contains(point) } }
            ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return .zero }
        var point = saved ?? NSPoint(x: visible.maxX - Self.collapsedSize.width - 20,
                                     y: visible.minY + Self.collapsedSize.height + 20)
        point.x = min(max(point.x, visible.minX + 8), visible.maxX - size.width - 8)
        point.y = min(max(point.y, visible.minY + size.height + 8), visible.maxY - 8)
        return point
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.collapsedSize),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = Settings.shared.hideWhileScreenSharing ? .none : .readOnly
        panel.contentView = NSHostingView(rootView: ShelfView(model: model))
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel,
                                               queue: .main) { [weak panel] _ in
            guard let frame = panel?.frame else { return }
            UserDefaults.standard.set(NSStringFromPoint(NSPoint(x: frame.minX, y: frame.maxY)),
                                      forKey: Self.positionKey)
        }
        self.panel = panel
        return panel
    }
}

@Observable
@MainActor
final class ShelfModel {
    private(set) var items: [ClipItem] = []
    var expanded = false { didSet { if expanded != oldValue { onChange?() } } }
    var listMode = false
    @ObservationIgnored var onChange: (() -> Void)?

    func add(_ item: ClipItem) {
        // The same copy or file again moves to the top instead of doubling.
        items.removeAll { $0.id == item.id || $0.sameContent(as: item) }
        items.append(item)
        onChange?()
    }

    func remove(_ removed: [ClipItem]) {
        let ids = Set(removed.map(\.id))
        items.removeAll { ids.contains($0.id) }
        onChange?()
    }

    func clear() {
        items.removeAll()
        onChange?()
    }

    /// "2 Documents", "3 Images", "4 Items" for a mix.
    static func title(for items: [ClipItem]) -> String {
        let kinds = Set(items.map(kind))
        let word = kinds.count == 1 ? kinds.first! : "Item"
        return "\(items.count) \(word)\(items.count == 1 ? "" : "s")"
    }

    private static func kind(_ item: ClipItem) -> String {
        switch item.type {
        case .image: "Image"
        case .file: ClipPreviewProvider.imageFileURL(for: item) != nil ? "Image" : "Document"
        case .link: "Link"
        case .color: "Color"
        case .text, .richText: "Text"
        }
    }

    /// Files on disk behind the items, for their size and Reveal in Finder.
    static func fileURLs(of items: [ClipItem]) -> [URL] {
        items.flatMap { item -> [URL] in
            switch item.type {
            case .file: item.fileURLs.compactMap(URL.init(string:)).filter(\.isFileURL)
            case .image: ClipboardStore.shared.imageURL(for: item).map { [$0] } ?? []
            default: []
            }
        }
    }

    static func sizeText(of items: [ClipItem]) -> String? {
        let bytes = fileURLs(of: items).reduce(Int64(0)) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return bytes > 0 ? ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) : nil
    }
}

// MARK: - Views

struct ShelfView: View {
    @Bindable var model: ShelfModel

    var body: some View {
        ZStack {
            WindowDragArea()
            VStack(alignment: .leading, spacing: 10) {
                header
                if model.expanded { expanded } else { collapsed }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // The Paste Stack's surface, corner and hairline, so both read as one.
        .background {
            ZStack {
                VisualEffectView(material: .popover)
                Theme.panelTint
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .strokeBorder(Theme.cardBorder))
    }

    /// Only two quiet round buttons, as in Dropover, so the Shelf does not
    /// pull the eye away from the windows around it.
    private var header: some View {
        HStack(spacing: 8) {
            HeaderButton(symbol: "xmark", filled: true, help: "Close the Shelf") { model.clear() }
            Spacer(minLength: 8)
            if model.expanded {
                HeaderButton(symbol: model.listMode ? "square.grid.2x2" : "list.bullet", filled: true,
                             help: model.listMode ? "Show as tiles" : "Show as list") { model.listMode.toggle() }
                HeaderButton(symbol: "chevron.left", filled: true, help: "Back to the stack") { model.expanded = false }
            }
            Menu {
                actions(for: model.items)
                Divider()
                Button("Close Shelf") { model.clear() }
            } label: {
                HeaderButtonLabel(symbol: "ellipsis", filled: true)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
    }

    // MARK: Stack

    private var collapsed: some View {
        VStack(spacing: 10) {
            ZStack {
                let shown = Array(ShelfStackCard.cards(for: model.items).suffix(4))
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, card in
                    let fromTop = shown.count - 1 - index
                    ShelfStackCard(card: card, side: 84)
                        .rotationEffect(.degrees(ShelfStackCard.rotations[fromTop]))
                        .offset(ShelfStackCard.offsets[fromTop])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                ShelfDragSource(items: { model.items },
                                onClick: { model.expanded = true },
                                menu: { menuItems(for: model.items) },
                                onDragged: { model.remove($0) })
            }
            .help("Drag everything into an app, or click to see each item")

            Button { model.expanded = true } label: {
                HStack(spacing: 5) {
                    Text(ShelfModel.title(for: model.items))
                        .font(.system(size: 11.5, weight: .regular))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.chromeTextSecondary)
                }
            }
            .buttonStyle(ChromePillButtonStyle())
        }
    }

    // MARK: Open

    @ViewBuilder
    private var expanded: some View {
        if model.listMode {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.items.reversed()) { item in row(item) }
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(model.items.reversed()) { item in tile(item) }
                    if !ShelfModel.fileURLs(of: model.items).isEmpty { revealTile }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func tile(_ item: ClipItem) -> some View {
        VStack(spacing: 5) {
            ShelfThumbnail(item: item, side: 84)
                .frame(height: 92)
            Text(ShelfItemText.name(of: item))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.chromeTextPrimary)
                .lineLimit(1).truncationMode(.middle)
            Text(ShelfItemText.detail(of: item))
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(Theme.chromeTextSecondary)
                .lineLimit(1)
        }
        .frame(width: 112)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .overlay { dragSource(for: item) }
    }

    private func row(_ item: ClipItem) -> some View {
        HStack(spacing: 10) {
            ShelfThumbnail(item: item, side: 28)
            Text(ShelfItemText.name(of: item))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.chromeTextPrimary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(ShelfItemText.detail(of: item))
                .font(.system(size: 11.5, weight: .light))
                .foregroundStyle(Theme.chromeTextSecondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(Theme.pillSelected, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay { dragSource(for: item) }
    }

    /// Clicked through the same AppKit view as the tiles: a SwiftUI Button in
    /// the horizontal scroll view of this non-activating panel never fired.
    private var revealTile: some View {
        VStack(spacing: 5) {
            Image(systemName: "arrowshape.turn.up.right.circle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Theme.chromeTextSecondary)
                .frame(height: 92)
            Text("Reveal in Finder")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.chromeTextPrimary)
            Text(" ").font(.system(size: 11))
        }
        .frame(width: 112)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .overlay {
            ShelfDragSource(items: { [] },
                            onClick: { NSWorkspace.shared.activateFileViewerSelecting(ShelfModel.fileURLs(of: model.items)) },
                            onDragged: { _ in })
        }
        .help("Show the files in Finder")
    }

    private func dragSource(for item: ClipItem) -> some View {
        ShelfDragSource(items: { [item] },
                        onDoubleClick: { ShelfActions.open(item) },
                        menu: { menuItems(for: [item]) + [ShelfMenuItem(title: "Remove from Shelf") { model.remove([item]) }] },
                        onDragged: { model.remove($0) })
    }

    @ViewBuilder
    private func actions(for items: [ClipItem]) -> some View {
        ForEach(menuItems(for: items)) { entry in
            Button(entry.title, action: entry.action)
        }
    }

    private func menuItems(for items: [ClipItem]) -> [ShelfMenuItem] {
        var entries = [
            ShelfMenuItem(title: items.count == 1 ? "Copy" : "Copy All") { ShelfActions.copy(items) },
            ShelfMenuItem(title: items.count == 1 ? "Add to Paste Stack" : "Add All to Paste Stack") {
                PasteStack.shared.add(items)
            }
        ]
        let urls = ShelfModel.fileURLs(of: items)
        if !urls.isEmpty {
            entries.append(ShelfMenuItem(title: "Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            })
        }
        if items.count == 1, let item = items.first {
            entries.insert(ShelfMenuItem(title: "Open") { ShelfActions.open(item) }, at: 0)
        }
        return entries
    }
}

/// The Shelf's round header buttons, sized like Dropover's.
private struct HeaderButton: View {
    let symbol: String
    var filled = false
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { HeaderButtonLabel(symbol: symbol, filled: filled) }
            .buttonStyle(.plain)
            .help(help)
    }
}

private struct HeaderButtonLabel: View {
    let symbol: String
    var filled: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.chromeTextPrimary.opacity(0.85))
            .frame(width: 30, height: 30)
            .background(filled ? Theme.fieldBG : Color.clear, in: Circle())
            .contentShape(Circle())
    }
}

/// One card of the collapsed stack. Every card gets the same rounded page
/// with a hairline edge and its own shadow, so several files read as a pile,
/// as in Dropover, even when their previews look alike.
struct ShelfStackCard: View {
    struct Card: Identifiable {
        let id: String
        let item: ClipItem
        let url: URL?
    }

    /// The top card lies straight, the ones below fan out a little more each.
    static let rotations: [Double] = [0, -6, 5, -10]
    static let offsets: [CGSize] = [.zero, CGSize(width: -5, height: 2),
                                    CGSize(width: 6, height: 3), CGSize(width: -8, height: 4)]

    /// A clip holding several files shows a card for each file.
    @MainActor
    static func cards(for items: [ClipItem]) -> [Card] {
        items.flatMap { item -> [Card] in
            let urls = ShelfModel.fileURLs(of: [item])
            guard item.type == .file, urls.count > 1 else {
                return [Card(id: item.id.uuidString, item: item, url: urls.first)]
            }
            return urls.map { Card(id: item.id.uuidString + $0.path, item: item, url: $0) }
        }
    }

    let card: Card
    let side: CGFloat
    @State private var image: NSImage?

    private var isPicture: Bool {
        card.item.type == .image || ClipPreviewProvider.imageFileURL(for: card.item) != nil
    }

    var body: some View {
        Group {
            if card.item.type == .color || (card.url == nil && card.item.type != .text
                                            && card.item.type != .richText && card.item.type != .link) {
                ShelfThumbnail(item: card.item, side: side)
            } else if let image, isPicture {
                Image(nsImage: image)
                    .resizable().interpolation(.high).scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1.5)
                    .frame(width: side, height: side)
            } else {
                page
            }
        }
        .task(id: card.id) {
            guard let url = card.url else { return }
            image = await ShelfThumbnails.image(for: url, side: side)
        }
    }

    /// A portrait sheet: the file's preview from the top, or the clip's text.
    private var page: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return ZStack(alignment: .topLeading) {
            Color.white
            if let image {
                Image(nsImage: image)
                    .resizable().interpolation(.high).scaledToFill()
                    .frame(width: side * 0.72, height: side * 0.92, alignment: .topLeading)
                    .clipped()
            } else if card.url == nil {
                ShelfThumbnail(item: card.item, side: side)
            }
        }
        .frame(width: side * 0.72, height: side * 0.92)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1.5)
    }
}

/// A file's QuickLook thumbnail, a picture, a sheet of text or a color.
struct ShelfThumbnail: View {
    let item: ClipItem
    let side: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable().interpolation(.high).scaledToFit()
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .task(id: item.id) { image = await ShelfThumbnails.image(for: item, side: side) }
    }

    @ViewBuilder
    private var placeholder: some View {
        switch item.type {
        case .color:
            RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                .fill(Color(hex: item.colorHex ?? "#000") ?? .black)
                .frame(width: side * 0.8, height: side * 0.8)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        case .link:
            paper {
                VStack(spacing: side * 0.06) {
                    Image(systemName: "globe").font(.system(size: side * 0.22, weight: .light))
                    Text(URL(string: item.text ?? "")?.host() ?? item.text ?? "")
                        .font(.system(size: max(5, side * 0.08)))
                        .lineLimit(2)
                }
                .foregroundStyle(Color.black.opacity(0.6))
            }
        case .text, .richText:
            paper {
                Text(item.text ?? "")
                    .font(.system(size: max(3, side * 0.055)))
                    .foregroundStyle(Color.black.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        case .image, .file:
            Image(nsImage: ClipPreviewProvider.cachedIcon(for: item)
                  ?? NSWorkspace.shared.icon(for: .data))
                .resizable().scaledToFit()
        }
    }

    /// A white page in portrait, like a document's preview.
    private func paper<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(side * 0.07)
            .frame(width: side * 0.72, height: side * 0.92)
            .background(.white, in: RoundedRectangle(cornerRadius: side * 0.05))
            .clipped()
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }
}

@MainActor
enum ShelfThumbnails {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for item: ClipItem, side: CGFloat) async -> NSImage? {
        guard let url = ShelfModel.fileURLs(of: [item]).first else { return nil }
        return await image(for: url, side: side)
    }

    static func image(for url: URL, side: CGFloat) async -> NSImage? {
        let key = "\(url.path)|\(Int(side))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side),
                                                   scale: scale, representationTypes: .thumbnail)
        let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        let image = representation?.nsImage ?? NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(image, forKey: key)
        return image
    }

    /// A picture of the item for the drag: its loaded thumbnail when there is
    /// one, otherwise the page, swatch or icon the Shelf draws for it.
    static func dragImage(for item: ClipItem, side: CGFloat) -> NSImage {
        if let url = ShelfModel.fileURLs(of: [item]).first {
            for size in [84, 72, 28] {
                if let cached = cache.object(forKey: "\(url.path)|\(size)" as NSString) { return cached }
            }
        }
        let renderer = ImageRenderer(content: ShelfThumbnail(item: item, side: side).padding(4))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage ?? NSWorkspace.shared.icon(for: .data)
    }
}

enum ShelfItemText {
    @MainActor
    static func name(of item: ClipItem) -> String {
        switch item.type {
        case .file:
            item.fileURLs.first.flatMap(URL.init(string:))?.lastPathComponent ?? item.displayTitle
        case .image:
            "Image"
        case .color:
            (item.colorHex ?? "").uppercased()
        case .link, .text, .richText:
            (item.text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        }
    }

    @MainActor
    static func detail(of item: ClipItem) -> String {
        if let size = ShelfModel.sizeText(of: [item]) { return size }
        switch item.type {
        case .link: return URL(string: item.text ?? "")?.host() ?? "Link"
        case .color: return "Color"
        default: return "\((item.text ?? "").count) characters"
        }
    }
}

@MainActor
enum ShelfActions {
    /// A file opens in its app; a clip opens the bar.
    static func open(_ item: ClipItem) {
        if let url = ShelfModel.fileURLs(of: [item]).first {
            NSWorkspace.shared.open(url)
        } else if item.type == .link, let url = URL(string: item.text ?? "") {
            NSWorkspace.shared.open(url)
        } else {
            AppController.shared.showBar()
        }
    }

    /// Copies without the copy landing on the Shelf again.
    static func copy(_ items: [ClipItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.flatMap(writers(for:)))
        AppController.shared.monitor.suppressUntilChangeCount = pasteboard.changeCount
    }

    /// What a dragged item offers. Text, rich text and colors arrive in
    /// Finder as a file named after their first line, and in a text field
    /// as their text; everything else as in `writers(for:)`.
    static func dragWriters(for item: ClipItem) -> [NSPasteboardWriting] {
        guard Settings.shared.shelfTextAsFile else { return writers(for: item) }
        switch item.type {
        case .text, .color:
            let text = item.plainText ?? ""
            return [ShelfTextFile(name: ShelfTextFile.fileName(for: text, fallback: "Text"), ext: "txt",
                                  type: .plainText, data: Data(text.utf8), text: text)]
        case .richText:
            let text = item.text ?? ""
            if let rtf = item.rtfData {
                return [ShelfTextFile(name: ShelfTextFile.fileName(for: text, fallback: "Text"), ext: "rtf",
                                      type: .rtf, data: rtf, text: text)]
            }
            return [ShelfTextFile(name: ShelfTextFile.fileName(for: text, fallback: "Text"), ext: "txt",
                                  type: .plainText, data: Data(text.utf8), text: text)]
        default:
            return writers(for: item)
        }
    }

    /// What a dragged or copied item puts on the pasteboard. Images go as a
    /// file with a readable name, so Finder and Mail receive a real file.
    static func writers(for item: ClipItem) -> [NSPasteboardWriting] {
        switch item.type {
        case .file:
            let urls = item.fileURLs.compactMap(URL.init(string:)).filter(\.isFileURL)
            if !urls.isEmpty { return urls as [NSURL] }
        case .image:
            if let url = namedImageCopy(of: item) { return [url as NSURL] }
        case .link:
            if let url = URL(string: item.text ?? "") { return [url as NSURL] }
        case .color:
            return [(item.colorHex ?? "") as NSString]
        case .text, .richText:
            break
        }
        return [(item.text ?? item.displayTitle) as NSString]
    }

    private static func namedImageCopy(of item: ClipItem) -> URL? {
        guard let source = ClipboardStore.shared.imageURL(for: item) else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Pastely Shelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "Image \(formatter.string(from: item.createdAt)).\(source.pathExtension)"
        let target = folder.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.copyItem(at: source, to: target)
        }
        return FileManager.default.fileExists(atPath: target.path) ? target : source
    }
}

// MARK: - AppKit drag source

struct ShelfMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
}

/// Clicks, double-clicks, right-clicks and drags on Shelf items. Done in
/// AppKit because only an NSDraggingSource hears whether a drop landed,
/// which is when the Shelf lets go of what was dragged.
struct ShelfDragSource: NSViewRepresentable {
    let items: () -> [ClipItem]
    var onClick: (() -> Void)? = nil
    var onDoubleClick: (() -> Void)? = nil
    var menu: () -> [ShelfMenuItem] = { [] }
    let onDragged: ([ClipItem]) -> Void

    func makeNSView(context: Context) -> ShelfDragSourceView { ShelfDragSourceView() }

    func updateNSView(_ view: ShelfDragSourceView, context: Context) {
        view.items = items
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        view.menuItems = menu
        view.onDragged = onDragged
    }
}

final class ShelfDragSourceView: NSView, NSDraggingSource {
    var items: () -> [ClipItem] = { [] }
    var onClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var menuItems: () -> [ShelfMenuItem] = { [] }
    var onDragged: ([ClipItem]) -> Void = { _ in }

    private var downEvent: NSEvent?
    private var dragging = false
    private var draggedItems: [ClipItem] = []

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downEvent = event
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = downEvent, !dragging else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        guard dx * dx + dy * dy > 16 else { return }
        dragging = true
        startDrag(with: down)
    }

    override func mouseUp(with event: NSEvent) {
        defer { downEvent = nil }
        guard !dragging else { return }
        if event.clickCount == 2 { onDoubleClick?() } else if event.clickCount == 1 { onClick?() }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let entries = menuItems()
        guard !entries.isEmpty else { return nil }
        let menu = NSMenu()
        for entry in entries { menu.addItem(ClosureMenuItem(title: entry.title, action: entry.action)) }
        return menu
    }

    private func startDrag(with event: NSEvent) {
        let items = self.items()
        guard !items.isEmpty else { return }
        draggedItems = items
        // Under the pointer, each item's own picture, fanned out a little.
        let pointer = convert(event.locationInWindow, from: nil)
        let side: CGFloat = 72
        var draggingItems: [NSDraggingItem] = []
        for (index, item) in items.reversed().enumerated() {
            let image = MainActor.assumeIsolated { ShelfThumbnails.dragImage(for: item, side: side) }
            for (writerIndex, writer) in ShelfActions.dragWriters(for: item).enumerated() {
                let draggingItem = NSDraggingItem(pasteboardWriter: writer)
                let offset = CGFloat(min(index, 4)) * 8
                let frame = NSRect(x: pointer.x - side / 2 + offset, y: pointer.y - side / 2 - offset,
                                   width: side, height: side)
                draggingItem.setDraggingFrame(frame, contents: writerIndex == 0 ? image : nil)
                draggingItems.append(draggingItem)
            }
        }
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .generic] : [.copy, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        let dragged = draggedItems
        draggedItems = []
        dragging = false
        guard operation != [] else { return }
        MainActor.assumeIsolated {
            if Settings.shared.shelfRemoveAfterDrag { onDragged(dragged) }
        }
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() { handler() }
}

/// Empty space that moves the window, as a title bar would.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { MoveView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class MoveView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

/// A text clip on its way out of the Shelf: a file for Finder, written when
/// it is dropped, and plain text for anything that takes text.
final class ShelfTextFile: NSFilePromiseProvider, NSFilePromiseProviderDelegate {
    private let name: String
    private let data: Data
    private let text: String

    init(name: String, ext: String, type: UTType, data: Data, text: String) {
        self.name = "\(name).\(ext)"
        self.data = data
        self.text = text
        super.init()
        fileType = type.identifier
        delegate = self
    }

    /// The first line, cut to a sensible length and cleared of characters
    /// a file name cannot hold.
    static func fileName(for text: String, fallback: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let cleaned = firstLine
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        let short = String(cleaned.prefix(60)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? fallback : short
    }

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        super.writableTypes(for: pasteboard) + [.string]
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        type == .string ? text : super.pasteboardPropertyList(forType: type)
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        name
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL,
                             completionHandler: @escaping (Error?) -> Void) {
        do {
            try data.write(to: Self.freeURL(near: url), options: .withoutOverwriting)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    /// "Notiz.txt", or "Notiz 2.txt" when that name is taken.
    static func freeURL(near url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent()
        var n = 2
        while true {
            let candidate = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(url.pathExtension)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }
}
