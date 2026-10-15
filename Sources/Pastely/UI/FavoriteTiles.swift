import AppKit
import SwiftUI

/// Favorites at the start of Clipboard: four small tiles in the space of one
/// card, as many blocks as it takes. A click pastes, as quick as a shortcut.
struct FavoriteBlocks: View {
    @Bindable private var store = ClipboardStore.shared

    static let perBlock = 4

    var body: some View {
        let groups = stride(from: 0, to: store.favorites.count, by: Self.perBlock).map {
            Array(store.favorites[$0..<min($0 + Self.perBlock, store.favorites.count)])
        }
        ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    tile(group, 0)
                    tile(group, 1)
                }
                GridRow {
                    tile(group, 2)
                    tile(group, 3)
                }
            }
            .frame(width: Theme.cardWidth)
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func tile(_ group: [ClipItem], _ index: Int) -> some View {
        if group.indices.contains(index) {
            FavoriteTile(item: group[index])
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct FavoriteTile: View {
    let item: ClipItem
    @State private var hovering = false
    @State private var preview: NSImage?
    private var store: ClipboardStore { .shared }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cardBody)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Theme.cardBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { AppController.shared.pasteItem(item) }
        .onDrag { ClipDragProvider.make(for: item) }
        .help("Click to paste \(item.displayTitle)")
        .contextMenu { menu }
        .task(id: item.id) {
            if ClipPreviewProvider.showsImage(item) {
                preview = await ClipPreviewProvider.image(for: item, scale: NSScreen.main?.backingScaleFactor ?? 2)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .regular))
            Text(item.customTitle ?? item.type.label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(nsImage: AppIconProvider.icon(forBundleID: item.sourceBundleID))
                .resizable().interpolation(.high)
                .frame(width: 16, height: 16)
        }
        .foregroundStyle(Theme.headerText)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(SourceColor.color(for: item.sourceBundleID))
    }

    @ViewBuilder
    private var content: some View {
        switch item.type {
        case .color:
            ZStack {
                Color(hex: item.colorHex ?? "#000") ?? .black
                Text((item.colorHex ?? "").uppercased())
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(colorInk)
            }
        case .image:
            imageContent
        case .file:
            if ClipPreviewProvider.showsImage(item) {
                imageContent
            } else {
                VStack(spacing: 4) {
                    Image(nsImage: ClipPreviewProvider.cachedIcon(for: item)
                          ?? NSWorkspace.shared.icon(for: .data))
                        .resizable().scaledToFit().frame(width: 30, height: 30)
                    Text(item.displayTitle)
                        .font(.system(size: 10.5, weight: .light))
                        .foregroundStyle(Theme.cardTextSecondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                .padding(6)
            }
        case .link:
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: "link").font(.system(size: 11, weight: .light))
                Text(item.displayTitle)
                    .font(.system(size: 11.5, weight: .light))
                    .lineLimit(3)
            }
            .foregroundStyle(Theme.cardTextPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
        case .text, .richText:
            Text(item.text ?? "")
                .font(.system(size: 11.5, weight: .light))
                .foregroundStyle(Theme.cardTextPrimary)
                .lineLimit(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        }
    }

    private var imageContent: some View {
        GeometryReader { geo in
            ZStack {
                CheckerboardBackground()
                if let image = preview ?? ClipPreviewProvider.cachedImage(for: item) {
                    Image(nsImage: image)
                        .resizable().interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
    }

    private var colorInk: Color {
        guard let ns = NSColor(hex: item.colorHex ?? "")?.usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return luminance > 0.6 ? .black.opacity(0.78) : .white.opacity(0.95)
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
        Button { AppController.shared.copyItem(item) } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Divider()
        Button { store.moveFavorite(item, by: -1) } label: { Label("Move Left", systemImage: "arrow.left") }
            .disabled(store.favorites.first?.id == item.id)
        Button { store.moveFavorite(item, by: 1) } label: { Label("Move Right", systemImage: "arrow.right") }
            .disabled(store.favorites.last?.id == item.id)
        Divider()
        Button { store.removeFavorite(item) } label: {
            Label("Remove from Favorites", systemImage: "star.slash")
        }
    }
}
