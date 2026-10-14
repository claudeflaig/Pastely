import SwiftUI

struct PinboardTabs: View {
    @Bindable private var store = ClipboardStore.shared
    /// The tab a card is being dragged over, highlighted as a drop target.
    @State private var dropTarget: UUID?
    /// The tab being dragged to a new place, told apart from a dragged card.
    @State private var draggedBoard: UUID?
    private var cleanShot: CleanShotLibrary { CleanShotLibrary.shared }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                pill(title: "Clipboard",
                     dot: nil,
                     icon: "clock",
                     selected: store.source == .history) {
                    store.source = .history; store.selectFirst()
                }

                ForEach(store.pinboards) { board in
                    pill(title: board.name,
                         dot: board.color,
                         selected: store.source == .pinboard(board.id) || dropTarget == board.id) {
                        store.source = .pinboard(board.id); store.selectFirst()
                    }
                    // Dropping a card on a tab saves it there, as in Paste.
                    .onDrop(of: [.item], isTargeted: Binding(
                        get: { dropTarget == board.id },
                        set: { dropTarget = $0 ? board.id : (dropTarget == board.id ? nil : dropTarget) }
                    )) { _ in
                        if let dragged = draggedBoard {
                            draggedBoard = nil
                            withAnimation(.easeOut(duration: 0.2)) { store.movePinboard(dragged, to: board.id) }
                            return true
                        }
                        guard let item = ClipDragProvider.recentlyDraggedItem else { return false }
                        ClipDragProvider.clearDraggedItem()
                        store.saveToPinboard(item, boardID: board.id)
                        return true
                    }
                    // Dragging a tab onto another one reorders the pinboards.
                    .onDrag {
                        draggedBoard = board.id
                        ClipDragProvider.clearDraggedItem()
                        return NSItemProvider(object: board.name as NSString)
                    }
                    // Rename lived only in the context menu, which nobody found (#100).
                    .simultaneousGesture(TapGesture(count: 2).onEnded { rename(board) })
                    .help("Double-click or right-click to rename")
                    .contextMenu {
                        Button("Rename…") { rename(board) }
                        Button("Move Left") { store.movePinboard(board.id, by: -1) }
                            .disabled(store.pinboards.first?.id == board.id)
                        Button("Move Right") { store.movePinboard(board.id, by: 1) }
                            .disabled(store.pinboards.last?.id == board.id)
                        Menu("Color") {
                            ForEach(ClipboardStore.pinboardColors, id: \.self) { hex in
                                Button {
                                    store.recolorPinboard(board.id, to: hex)
                                } label: {
                                    Label {
                                        Text(Self.colorName(hex))
                                    } icon: {
                                        Image(nsImage: Self.dot(hex))
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("Delete Pinboard", role: .destructive) {
                            store.deletePinboard(board.id)
                        }
                    }
                }

                if cleanShot.isAvailable {
                    pill(title: "CleanShot",
                         dot: nil,
                         icon: "camera.viewfinder",
                         selected: store.source == .cleanShot) {
                        cleanShot.refresh()
                        store.source = .cleanShot; store.selectFirst()
                    }
                    .help("Your CleanShot X capture history")
                }

                ForEach(FolderLibrary.shared.folders, id: \.self) { path in
                    pill(title: FolderLibrary.title(for: path),
                         dot: nil,
                         icon: path == Settings.downloadsPath ? "arrow.down.circle" : "folder",
                         selected: store.source == .folder(path)) {
                        FolderLibrary.shared.refresh(path)
                        store.source = .folder(path); store.selectFirst()
                    }
                    .help(path)
                }

                Button(action: addPinboard) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.chromeTextSecondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("New Pinboard")
            }
        }
    }

    private func pill(title: String, dot: Color?, icon: String? = nil,
                      selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                if let dot {
                    Circle().fill(dot).frame(width: 11, height: 11)
                }
                Text(title)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Theme.chromeTextPrimary : Theme.chromeTextSecondary)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(selected ? Theme.pillSelected : Theme.pillBG, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    private static func colorName(_ hex: String) -> String {
        ["#FF5F57": "Red", "#FEBC2E": "Yellow", "#28C840": "Green", "#2F80ED": "Blue",
         "#A259FF": "Purple", "#FF8A00": "Orange", "#FF4FA0": "Pink", "#19B5C6": "Teal"][hex] ?? hex
    }

    /// Menus drop SwiftUI shapes, so the swatch is drawn as an image.
    private static func dot(_ hex: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            (NSColor(hex: hex) ?? .gray).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func addPinboard() {
        let board = store.addPinboard(name: "New Pinboard")
        store.source = .pinboard(board.id)
    }

    private func rename(_ board: Pinboard) {
        if let name = TextPrompt.run(title: "Rename Pinboard",
                                     message: "Enter a new name",
                                     defaultValue: board.name) {
            store.renamePinboard(board.id, to: name)
        }
    }
}

@MainActor
enum TextPrompt {
    /// `allowEmpty` lets an empty answer through, for prompts where clearing
    /// the field means removing the value.
    static func run(title: String, message: String, defaultValue: String = "",
                    allowEmpty: Bool = false) -> String? {
        AppController.shared.suppressAutoHide = true
        defer { AppController.shared.suppressAutoHide = false }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let v = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty && !allowEmpty ? nil : v
    }
}
