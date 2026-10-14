import AppKit
import ImageIO
import SwiftUI

struct ClipCardView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool

    @State private var hovering = false
    @State private var preview: NSImage?
    @State private var previewFailed = false
    @State private var fileInfo: ClipPreviewProvider.FileInfo?
    @State private var linkPreview: LinkPreview?
    private var store: ClipboardStore { ClipboardStore.shared }
    private var settings: Settings { Settings.shared }
    private var headerColor: Color { SourceColor.color(for: item.sourceBundleID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            body_
        }
        .frame(width: Theme.cardWidth)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .background {
            if selected {
                RoundedRectangle(
                    cornerRadius: Theme.cardCorner + Theme.selectedCardRing,
                    style: .continuous
                )
                .fill(Theme.selection)
                .padding(-Theme.selectedCardRing)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(selected ? Theme.selection : Theme.cardBorder,
                              lineWidth: selected ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        .scaleEffect(hovering && !selected ? 1.015 : 1.0)
        .zIndex(selected ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { AppController.shared.pasteItem(item) }
        .onTapGesture { store.select(item.id) }
        .highPriorityGesture(TapGesture().modifiers(.shift).onEnded { store.extendSelection(to: item.id) })
        .highPriorityGesture(TapGesture().modifiers(.command).onEnded { store.toggleSelection(item.id) })
        .onDrag { ClipDragProvider.make(for: item) }
        .contextMenu { menu }
        .task(id: item.id) { await loadPreview() }
    }

    /// Paste's header: type and age on the left, and the source app's icon
    /// oversized at the right edge so the header clips part of it.
    private var header: some View {
        ZStack(alignment: .leading) {
            headerColor
            VStack(alignment: .leading, spacing: 1) {
                Text(customTitle ?? cardTypeLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.headerText)
                HStack(spacing: 6) {
                    // A renamed card shows its name alone, as Paste does.
                    if customTitle == nil {
                        Text(item.createdAt.clipRelativeLong)
                            .font(.system(size: 12.5, weight: .light))
                            .foregroundStyle(Theme.headerSubText)
                    }
                    if let abbreviation = item.abbreviation {
                        Text(abbreviation)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.headerText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.25), in: Capsule())
                            .help("Type \(abbreviation) anywhere to insert this clip")
                    }
                }
            }
            .lineLimit(1)
            .padding(.leading, 14)
            .padding(.trailing, Theme.appIconSize - 4)
        }
        .overlay(alignment: .trailing) { appIconTile }
        .frame(height: Theme.headerHeight)
        .clipped()
    }

    private var customTitle: String? {
        guard let title = item.customTitle?.trimmingCharacters(in: .whitespaces), !title.isEmpty else { return nil }
        return title
    }

    private var cardTypeLabel: String {
        if item.type == .file, item.fileURLs.count > 1 { return "\(item.fileURLs.count) files" }
        if let url = ClipPreviewProvider.imageFileURL(for: item) {
            return ScreenshotDetector.isScreenshot(url) ? "Screenshot" : "Image"
        }
        if item.type == .image { return "Image" }
        return item.type.label
    }

    private var appIconTile: some View {
        Image(nsImage: AppIconProvider.icon(forBundleID: item.sourceBundleID))
            .resizable()
            .interpolation(.high)
            .frame(width: Theme.appIconSize, height: Theme.appIconSize)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .offset(x: 10, y: -4)
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, fillsBody ? 0 : 16)
                .padding(.top, fillsBody ? 0 : 14)
            if !showsImage && item.type != .color {
                footer
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            // Paste floats an image's size on a dark pill over the picture.
            if showsImage {
                Text(metaLeft)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(.bottom, 10)
            }
        }
        .background(Theme.cardBody)
    }

    private var fillsBody: Bool {
        showsImage || item.type == .color
    }

    /// Dark text on light colors, white on dark ones.
    private var colorCardInk: Color {
        guard let ns = NSColor(hex: item.colorHex ?? "")?.usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return luminance > 0.6 ? .black.opacity(0.78) : .white.opacity(0.95)
    }

    /// Image clips, and file clips pointing at an image, which is how a copied
    /// screenshot usually arrives, run edge to edge instead of sitting inset.
    private var showsImage: Bool {
        ClipPreviewProvider.showsImage(item) && !previewFailed
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .image:
            imageCanvas
        case .color:
            // Paste floods the whole card body with the color and centers the
            // hex code in a monospaced face that stays readable on it.
            ZStack {
                Color(hex: item.colorHex ?? "#000") ?? .black
                Text((item.colorHex ?? "").uppercased())
                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                    .foregroundStyle(colorCardInk)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .file:
            if showsImage {
                imageCanvas
            } else {
                fileContent
            }
        case .link:
            linkContent
        default:
            Text(item.text ?? "")
                .font(.system(size: 13.5, weight: .light))
                .lineSpacing(2)
                .foregroundStyle(Theme.cardTextPrimary)
                .lineLimit(10)
                .multilineTextAlignment(.leading)
        }
    }

    /// A link reads as a web page, not a picture: its preview image sits
    /// inset as a rounded thumbnail in the page's own 1.91:1 social-card
    /// shape, unlike screenshots, which run edge to edge. A site without an
    /// image shows its favicon on a quiet tile instead.
    @ViewBuilder
    private var linkContent: some View {
        Group {
            if let image = linkPreview?.image, showsLinkHero {
                Color.clear
                    .overlay(
                        Image(nsImage: image)
                            .resizable().interpolation(.medium).scaledToFill()
                    )
            } else {
                ZStack {
                    Theme.fieldBG
                    if let icon = linkPreview?.icon ?? linkPreview?.image {
                        Image(nsImage: icon)
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "globe").font(.system(size: 30, weight: .light))
                            .foregroundStyle(Theme.cardTextTertiary)
                    }
                }
            }
        }
        .aspectRatio(1.91, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.cardBorder)
        )
    }

    /// Wide enough to be a page image rather than an icon.
    private var showsLinkHero: Bool {
        guard let size = linkPreview?.image?.size else { return false }
        return size.width >= 200 && size.width > size.height * 1.1
    }

    /// Over a checkerboard, so a transparent cut-out is distinguishable from
    /// an image on white. An image close to the card's shape fills it; a wide
    /// or tall one is shown whole, over a blurred copy of itself, instead of
    /// losing most of the picture to the crop. The image is sized to the
    /// canvas rather than the canvas to the image, so a large picture can no
    /// longer stretch the card past the bar.
    private var imageCanvas: some View {
        GeometryReader { geo in
            ZStack {
                CheckerboardBackground()
                if let image = preview ?? ClipPreviewProvider.cachedImage(for: item) {
                    let fills = Self.imageFillsCanvas(image.size, canvas: geo.size)
                    if !fills {
                        // Opaque blur, so the edges stay solid instead of
                        // fading to the checkerboard.
                        Image(nsImage: image)
                            .resizable().interpolation(.low).scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .blur(radius: 22, opaque: true)
                            .overlay(Color.black.opacity(0.12))
                            .clipped()
                    }
                    Image(nsImage: image)
                        .resizable().interpolation(.high)
                        .aspectRatio(contentMode: fills ? .fill : .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    placeholder("photo")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// Whether an image is close enough to the canvas's shape to fill it
    /// with only a slight crop.
    static func imageFillsCanvas(_ image: CGSize, canvas: CGSize) -> Bool {
        guard image.width > 0, image.height > 0, canvas.width > 0, canvas.height > 0 else { return true }
        let ratio = (image.width / image.height) / (canvas.width / canvas.height)
        return ratio > 0.75 && ratio < 1.33
    }

    @ViewBuilder
    private var fileContent: some View {
        VStack(spacing: 9) {
            if let icon = fileInfo?.icon ?? ClipPreviewProvider.cachedIcon(for: item) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Theme.fileIconSize, height: Theme.fileIconSize)
                    .opacity(fileInfo?.isMissing == true ? 0.5 : 1)
            } else {
                Image(systemName: "doc.fill").font(.system(size: 32, weight: .light))
                    .foregroundStyle(headerColor)
            }
            Text(item.displayTitle).font(.system(size: 12, weight: .light))
                .foregroundStyle(Theme.cardTextSecondary).lineLimit(2)
                .multilineTextAlignment(.center)
            if fileInfo?.isMissing == true {
                Text("File not found")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.cardTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The page's own title unless the user renamed the card.
    private var linkTitle: String {
        if let custom = item.customTitle, !custom.isEmpty { return custom }
        if let title = linkPreview?.title, !title.isEmpty { return title }
        return item.displayTitle
    }

    private func loadPreview() async {
        if let url = LinkPreviewProvider.url(for: item) {
            linkPreview = LinkPreviewProvider.cached(for: url)
            if linkPreview == nil, settings.linkPreviews {
                linkPreview = await LinkPreviewProvider.preview(for: url)
            }
            return
        }
        preview = ClipPreviewProvider.cachedImage(for: item)
        fileInfo = nil
        previewFailed = false
        if ClipPreviewProvider.showsImage(item) {
            if preview == nil {
                preview = await ClipPreviewProvider.image(for: item, scale: NSScreen.main?.backingScaleFactor ?? 2)
            }
            guard preview == nil, item.type == .file else { return }
            previewFailed = true
        }
        guard item.type == .file else { return }
        fileInfo = await ClipPreviewProvider.fileInfo(for: item)
    }

    private func placeholder(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 30, weight: .light))
            .foregroundStyle(Theme.cardTextTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Paste centers a single gray line under the content; a link instead
    /// gets its title over the address, left aligned.
    private var footer: some View {
        VStack(alignment: item.type == .link ? .leading : .center, spacing: 2) {
            if item.type == .link {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let icon = linkPreview?.icon {
                        Image(nsImage: icon)
                            .resizable().interpolation(.high)
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                    }
                    Text(linkTitle)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.cardTextPrimary)
                        .lineLimit(2)
                }
            }
            // A path is worth reading in full, so it wraps rather than
            // collapsing to an ellipsis; everything else stays one line.
            Text(metaLeft)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Theme.cardTextSecondary)
                .lineLimit(item.type == .file ? 3 : 1)
                .multilineTextAlignment(item.type == .link ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: item.type == .link ? .leading : .center)
        .overlay(alignment: .bottomTrailing) {
            // The quick-paste shortcut stays out of the way until hovered.
            if index < 9, hovering || selected {
                Text("\(settings.quickPasteModifierDisplay)\(index + 1)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.cardTextTertiary)
            }
        }
        .padding(.top, 8)
    }

    private var isSingleImageFile: Bool {
        ClipPreviewProvider.imageFileURL(for: item) != nil
    }

    /// NSHomeDirectory is the sandbox container in the App Store build, so the
    /// real home comes from the account record instead.
    private static let homePath: String = {
        if let home = getpwuid(getuid())?.pointee.pw_dir { return String(cString: home) }
        return NSHomeDirectory()
    }()

    private static func abbreviatedPath(_ path: String) -> String {
        if path == homePath { return "~" }
        guard path.hasPrefix(homePath + "/") else { return path }
        return "~" + path.dropFirst(homePath.count)
    }

    private var metaLeft: String {
        switch item.type {
        case .text, .richText:
            return "\(item.charCount) characters"
        case .link:
            // The domain alone; the title above already says which page.
            if let host = LinkPreviewProvider.url(for: item)?.host {
                return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
            return (item.text ?? "").replacingOccurrences(of: "https://", with: "")
                                    .replacingOccurrences(of: "http://", with: "")
        case .file:
            guard item.fileURLs.count == 1,
                  let url = item.fileURLs.first.flatMap(URL.init(string:)) else {
                return item.fileURLs
                    .compactMap { URL(string: $0)?.lastPathComponent }
                    .joined(separator: ", ")
            }
            // An image shows what it is, so its size is the useful fact; a
            // screenshot's path is a timestamped folder nobody reads. Files
            // without a preview get the full location instead, since two
            // documents of the same name differ only by where they live.
            if isSingleImageFile {
                guard let size = ImagePixelSize.of(url) else { return url.lastPathComponent }
                return "\(Int(size.width)) × \(Int(size.height))"
            }
            return Self.abbreviatedPath(url.path)
        case .image:
            guard let size = ImagePixelSize.of(item) else { return "Image" }
            return "\(Int(size.width)) × \(Int(size.height))"
        case .color:
            return item.colorHex ?? "Color"
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button { AppController.shared.pasteItem(item) } label: {
            Label(AppController.shared.pasteMenuTitle, systemImage: "doc.on.clipboard")
        }

        Button { AppController.shared.pasteItem(item, format: .plainText) } label: {
            Label("Paste as Plain Text", systemImage: "text.alignleft")
        }
        .disabled(item.plainText == nil)

        Button { AppController.shared.pasteItem(item, format: .cleanFormatting) } label: {
            Label("Paste with Clean Formatting", systemImage: "paintbrush")
        }
        .disabled(!FormatConverter.canConvert(item))

        Button { AppController.shared.pasteItem(item, format: .markdown) } label: {
            Label("Paste as Markdown", systemImage: "number")
        }
        .disabled(!FormatConverter.canConvert(item))

        Button { AppController.shared.copyItem(item) } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        Divider()

        Button { AppController.shared.editItem(item) } label: {
            Label("Edit", systemImage: "pencil")
        }
        .disabled(!isEditable)

        if writingToolsAvailable {
            Button { AppController.shared.editItem(item, launchWritingTools: true) } label: {
                Label("Writing Tools", systemImage: "pencil.and.scribble")
            }
        }

        Button { renameItem() } label: {
            Label("Rename…", systemImage: "pencil.line")
        }

        if case .pinboard = store.source {
            Button { setAbbreviation() } label: {
                Label(item.abbreviation == nil ? "Set Abbreviation…" : "Change Abbreviation…",
                      systemImage: "keyboard")
            }
        }

        Divider()

        Menu {
            if store.pinboards.isEmpty {
                Button("No Pinboards Yet") {}
                    .disabled(true)
            } else {
                ForEach(store.pinboards) { b in
                    Button { store.saveToPinboard(item, boardID: b.id) } label: {
                        Label {
                            Text(b.name)
                        } icon: {
                            Image(nsImage: Self.pinboardMenuIcon(color: NSColor(b.color)))
                                .renderingMode(.original)
                        }
                    }
                }
            }
            Divider()
            Button { pinToNewBoard() } label: {
                Label("Create Pinboard…", systemImage: "plus")
            }
        } label: {
            Label("Pin", systemImage: "pin")
        }

        Divider()

        Button { AppController.shared.showPreview(for: item) } label: {
            Label("Preview", systemImage: "eye")
        }

        Button { AppController.shared.showSharePicker(for: item) } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            AppController.shared.deleteSelection(containing: item)
        } label: {
            Label(deleteMenuTitle, systemImage: "trash")
        }
        // CleanShot's captures are deleted in CleanShot.
        .disabled(store.source == .cleanShot)
    }

    private var deleteMenuTitle: String {
        let count = store.multiSelectedIDs.contains(item.id) ? store.multiSelectedIDs.count : 1
        return count > 1 ? "Delete \(count) Clips" : "Delete"
    }

    private var isEditable: Bool {
        [.text, .richText, .link, .color].contains(item.type)
    }

    private var writingToolsAvailable: Bool {
        guard [.text, .richText, .link].contains(item.type) else { return false }
        guard #available(macOS 15.2, *) else { return false }
        return NSWritingToolsCoordinator.isWritingToolsAvailable
    }

    private func setAbbreviation() {
        let current = item.abbreviation ?? ""
        if let value = TextPrompt.run(title: "Abbreviation",
                                      message: "Type this anywhere to insert the clip, e.g. ;anam. Leave empty to remove it.",
                                      defaultValue: current, allowEmpty: true) {
            store.setAbbreviation(value, for: item)
        }
    }

    private func renameItem() {
        if let title = TextPrompt.run(title: "Rename", message: "Card title",
                                      defaultValue: item.customTitle ?? "") {
            store.setTitle(title, for: item)
        }
    }

    private func pinToNewBoard() {
        if let name = TextPrompt.run(title: "Create Pinboard", message: "Name") {
            let board = store.addPinboard(name: name)
            store.saveToPinboard(item, boardID: board.id)
        }
    }

    private static func pinboardMenuIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

/// The standard transparency checkerboard drawn behind image clips. A Canvas
/// rather than a tiled image: the pattern is a handful of rects, and this keeps
/// it resolution independent without shipping an asset.
private struct CheckerboardBackground: View {
    var square: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            let columns = Int(ceil(size.width / square))
            let rows = Int(ceil(size.height / square))
            for row in 0..<max(rows, 0) {
                for column in 0..<max(columns, 0) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * square,
                                      y: CGFloat(row) * square,
                                      width: square,
                                      height: square)
                    context.fill(Path(rect), with: .color(Color(white: 0.87)))
                }
            }
        }
        .drawingGroup()
    }
}

/// Reads an image clip's pixel dimensions from the file's metadata instead of
/// decoding it, and remembers them: the card footer asks on every render.
@MainActor
enum ImagePixelSize {
    private static var cache: [String: CGSize?] = [:]
    private static let cacheLimit = 512

    static func of(_ item: ClipItem) -> CGSize? {
        guard item.imageFileName != nil,
              let url = ClipboardStore.shared.imageURL(for: item) else { return nil }
        return of(url)
    }

    static func of(_ url: URL) -> CGSize? {
        let name = url.path
        if let cached = cache[name] { return cached }
        if cache.count >= cacheLimit { cache.removeAll() }
        let size = read(url)
        cache.updateValue(size, forKey: name)
        return size
    }

    private static func read(_ url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }
}
