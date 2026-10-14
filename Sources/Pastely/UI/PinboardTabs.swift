import SwiftUI

struct PinboardTabs: View {
    @Bindable private var store = ClipboardStore.shared
    /// The tab something is being dragged over, highlighted as a drop target.
    @State private var dropTarget: BarSource?
    /// The tab being dragged to a new place.
    @State private var draggedTab: BarSource?
    private var cleanShot: CleanShotLibrary { CleanShotLibrary.shared }

    /// Marks a drag as a tab, told apart from a dragged card: a cancelled
    /// drag leaves `draggedTab` set, so that alone cannot tell.
    private static let tabDragType = "ch.claudeflaig.pastely.tab"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                pill(title: "Clipboard",
                     dot: nil,
                     icon: "clock",
                     selected: store.source == .history) {
                    store.source = .history; store.selectFirst()
                }

                ForEach(store.barTabs, id: \.self) { tab in
                    tabPill(tab)
                        .onDrop(of: [.item], isTargeted: Binding(
                            get: { dropTarget == tab },
                            set: { dropTarget = $0 ? tab : (dropTarget == tab ? nil : dropTarget) }
                        )) { providers in
                            drop(providers, on: tab)
                        }
                        // Dragging a tab onto another one reorders the tabs.
                        .onDrag {
                            draggedTab = tab
                            ClipDragProvider.clearDraggedItem()
                            let provider = NSItemProvider(object: title(of: tab) as NSString)
                            provider.registerDataRepresentation(forTypeIdentifier: Self.tabDragType,
                                                                visibility: .all) { completion in
                                completion(Data(), nil)
                                return nil
                            }
                            return provider
                        }
                        .contextMenu { menu(for: tab) }
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

    @ViewBuilder
    private func tabPill(_ tab: BarSource) -> some View {
        let highlighted = store.source == tab || dropTarget == tab
        switch tab {
        case .pinboard(let id):
            if let board = store.pinboards.first(where: { $0.id == id }) {
                pill(title: board.name, dot: board.color, selected: highlighted) {
                    store.source = tab; store.selectFirst()
                }
                // Rename lived only in the context menu, which nobody found (#100).
                .simultaneousGesture(TapGesture(count: 2).onEnded { rename(board) })
                .help("Double-click or right-click to rename")
            }
        case .cleanShot:
            pill(title: "CleanShot", dot: nil, icon: "camera.viewfinder", selected: highlighted) {
                cleanShot.refresh()
                store.source = tab; store.selectFirst()
            }
            .help("Your CleanShot X capture history")
        case .folder(let path):
            pill(title: FolderLibrary.title(for: path),
                 dot: nil,
                 icon: path == Settings.downloadsPath ? "arrow.down.circle" : "folder",
                 selected: highlighted) {
                FolderLibrary.shared.refresh(path)
                store.source = tab; store.selectFirst()
            }
            .help(path)
        case .history:
            EmptyView()
        }
    }

    private func title(of tab: BarSource) -> String {
        switch tab {
        case .pinboard(let id): store.pinboards.first(where: { $0.id == id })?.name ?? "Pinboard"
        case .cleanShot: "CleanShot"
        case .folder(let path): FolderLibrary.title(for: path)
        case .history: "Clipboard"
        }
    }

    private func drop(_ providers: [NSItemProvider], on tab: BarSource) -> Bool {
        let isTabDrag = providers.contains { $0.registeredTypeIdentifiers.contains(Self.tabDragType) }
            // In case the mark gets lost on the way: a card drag always
            // leaves its clip behind, a tab drag clears it.
            || (draggedTab != nil && ClipDragProvider.recentlyDraggedItem == nil)
        if isTabDrag {
            guard let dragged = draggedTab else { return false }
            draggedTab = nil
            withAnimation(.easeOut(duration: 0.2)) { store.moveTab(dragged, onto: tab) }
            return true
        }
        // Dropping a card on a pinboard tab saves it there, as in Paste.
        guard case .pinboard(let boardID) = tab,
              let item = ClipDragProvider.recentlyDraggedItem else { return false }
        ClipDragProvider.clearDraggedItem()
        store.saveToPinboard(item, boardID: boardID)
        return true
    }

    @ViewBuilder
    private func menu(for tab: BarSource) -> some View {
        if case .pinboard(let id) = tab, let board = store.pinboards.first(where: { $0.id == id }) {
            Button("Rename…") { rename(board) }
        }
        Button("Move Left") { store.moveTab(tab, by: -1) }
            .disabled(store.barTabs.first == tab)
        Button("Move Right") { store.moveTab(tab, by: 1) }
            .disabled(store.barTabs.last == tab)
        if case .pinboard(let id) = tab {
            Menu("Color") {
                ForEach(ClipboardStore.pinboardColors, id: \.self) { hex in
                    Button {
                        store.recolorPinboard(id, to: hex)
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
                store.deletePinboard(id)
            }
        }
    }

    /// A tap gesture rather than a Button: a Button tracks the mouse itself and
    /// swallows the drag, so `.onDrag` on a tab never started.
    private func pill(title: String, dot: Color?, icon: String? = nil,
                      selected: Bool, action: @escaping () -> Void) -> some View {
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
        .contentShape(Capsule())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, action)
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
