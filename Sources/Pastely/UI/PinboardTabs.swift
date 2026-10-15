import SwiftUI

/// The bar's top row of tabs: Clipboard, then pinboards, pinboard folders,
/// CleanShot and Finder folders in the order they were dragged into.
struct PinboardTabs: View {
    @Bindable private var store = ClipboardStore.shared
    /// The tab something is being dragged over, highlighted as a drop target.
    @State private var dropTarget: BarSource?
    private var cleanShot: CleanShotLibrary { CleanShotLibrary.shared }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                TabPill(title: "Clipboard", icon: "clock", selected: store.source == .history) {
                    store.source = .history; store.selectFirst()
                }

                ForEach(store.barTabs, id: \.self) { tab in
                    tabPill(tab)
                        .onDrop(of: [.item], isTargeted: TabDrag.targetBinding($dropTarget, tab)) { providers in
                            drop(providers, on: tab)
                        }
                        .onDrag { TabDrag.begin(tab) }
                        .contextMenu { menu(for: tab) }
                }

                Menu {
                    Button("New Pinboard") { PinboardActions.addPinboard() }
                    Button("New Pinboard Folder") { PinboardActions.addGroup() }
                    Divider()
                    Button("Add Folder from Finder…", action: addFolder)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Theme.chromeTextSecondary)
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("New Pinboard, Pinboard Folder or Finder Folder")
            }
        }
    }

    @ViewBuilder
    private func tabPill(_ tab: BarSource) -> some View {
        let highlighted = store.source == tab
        let dropping = dropTarget == tab
        switch tab {
        case .pinboard(let id):
            if let board = store.pinboards.first(where: { $0.id == id }) {
                TabPill(title: board.name, dot: board.color, selected: highlighted, dropTarget: dropping) {
                    store.source = tab; store.selectFirst()
                }
                // Rename lived only in the context menu, which nobody found (#100).
                .simultaneousGesture(TapGesture(count: 2).onEnded { PinboardActions.rename(board) })
                .help("Double-click or right-click to rename")
            }
        case .group(let id):
            if let group = store.groups.first(where: { $0.id == id }) {
                // A folder stays lit while one of its pinboards is open.
                TabPill(title: group.name, icon: "folder",
                        selected: highlighted || store.group(for: store.source)?.id == id, dropTarget: dropping) {
                    store.source = tab; store.selectFirst()
                }
                .simultaneousGesture(TapGesture(count: 2).onEnded { PinboardActions.rename(group) })
                .help("Drop a pinboard tab here to move it into the folder")
            }
        case .cleanShot:
            TabPill(title: "CleanShot", icon: "camera.viewfinder", selected: highlighted, dropTarget: dropping) {
                cleanShot.refresh()
                store.source = tab; store.selectFirst()
            }
            .help("Your CleanShot X capture history")
        case .folder(let path):
            TabPill(title: FolderLibrary.title(for: path),
                    icon: path == Settings.downloadsPath ? "arrow.down.circle" : "folder.badge.gearshape",
                    selected: highlighted, dropTarget: dropping) {
                FolderLibrary.shared.refresh(path)
                store.source = tab; store.selectFirst()
            }
            .help(path)
        case .history:
            EmptyView()
        }
    }

    private func drop(_ providers: [NSItemProvider], on tab: BarSource) -> Bool {
        if let dragged = TabDrag.take(providers) {
            withAnimation(.easeOut(duration: 0.2)) {
                // A pinboard dropped on a folder goes into it.
                if case .group(let groupID) = tab, case .pinboard(let boardID) = dragged {
                    store.movePinboard(boardID, into: groupID)
                } else {
                    store.moveTab(dragged, onto: tab)
                }
            }
            return true
        }
        return PinboardActions.saveDraggedCard(on: tab)
    }

    @ViewBuilder
    private func menu(for tab: BarSource) -> some View {
        switch tab {
        case .pinboard(let id):
            if let board = store.pinboards.first(where: { $0.id == id }) {
                Button("Rename…") { PinboardActions.rename(board) }
                moveItems(tab)
                PinboardActions.folderMenu(for: board)
                PinboardActions.colorMenu(for: board)
                Divider()
                Button("Delete Pinboard", role: .destructive) { store.deletePinboard(id) }
            }
        case .group(let id):
            if let group = store.groups.first(where: { $0.id == id }) {
                Button("Rename…") { PinboardActions.rename(group) }
                Button("New Pinboard in Folder") { PinboardActions.addPinboard(in: id) }
                moveItems(tab)
                Divider()
                Button("Delete Folder (Keep Pinboards)", role: .destructive) { store.deleteGroup(id) }
            }
        case .folder(let path):
            moveItems(tab)
            Divider()
            Button("Remove from Bar") {
                if store.source == tab { store.source = .history; store.selectFirst() }
                FolderLibrary.shared.remove(path)
            }
        case .cleanShot:
            moveItems(tab)
        case .history:
            EmptyView()
        }
    }

    @ViewBuilder
    private func moveItems(_ tab: BarSource) -> some View {
        Button("Move Left") { store.moveTab(tab, by: -1) }
            .disabled(store.barTabs.first == tab)
        Button("Move Right") { store.moveTab(tab, by: 1) }
            .disabled(store.barTabs.last == tab)
    }

    private func addFolder() {
        guard let path = FolderLibrary.shared.chooseAndAdd() else { return }
        store.source = .folder(path); store.selectFirst()
    }
}

/// The second row under a pinboard folder's tab: All, then the folder's
/// pinboards, which drag, rename and take dropped cards like any pinboard.
struct PinboardGroupRow: View {
    let group: PinboardGroup
    @Bindable private var store = ClipboardStore.shared
    @State private var dropTarget: BarSource?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Theme.chromeTextTertiary)
                TabPill(title: "All", icon: "square.stack", compact: true,
                        selected: store.source == .group(group.id), dropTarget: dropTarget == .group(group.id)) {
                    store.source = .group(group.id); store.selectFirst()
                }
                .onDrop(of: [.item], isTargeted: TabDrag.targetBinding($dropTarget, .group(group.id))) { providers in
                    guard let dragged = TabDrag.take(providers), case .pinboard(let id) = dragged else { return false }
                    withAnimation(.easeOut(duration: 0.2)) { store.movePinboard(id, into: group.id) }
                    return true
                }

                ForEach(store.pinboards(in: group.id)) { board in
                    let tab = BarSource.pinboard(board.id)
                    TabPill(title: board.name, dot: board.color, compact: true,
                            selected: store.source == tab, dropTarget: dropTarget == tab) {
                        store.source = tab; store.selectFirst()
                    }
                    .simultaneousGesture(TapGesture(count: 2).onEnded { PinboardActions.rename(board) })
                    .help("Double-click or right-click to rename")
                    .onDrop(of: [.item], isTargeted: TabDrag.targetBinding($dropTarget, tab)) { providers in
                        if let dragged = TabDrag.take(providers) {
                            guard case .pinboard(let id) = dragged else { return false }
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.movePinboard(id, into: group.id, before: board.id)
                            }
                            return true
                        }
                        return PinboardActions.saveDraggedCard(on: tab)
                    }
                    .onDrag { TabDrag.begin(tab) }
                    .contextMenu {
                        Button("Rename…") { PinboardActions.rename(board) }
                        PinboardActions.folderMenu(for: board)
                        PinboardActions.colorMenu(for: board)
                        Divider()
                        Button("Delete Pinboard", role: .destructive) { store.deletePinboard(board.id) }
                    }
                }

                Button { PinboardActions.addPinboard(in: group.id) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Theme.chromeTextSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("New Pinboard in \(group.name)")
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 34)
    }
}

/// A tab. A tap gesture rather than a Button: a Button tracks the mouse
/// itself and swallows the drag, so `.onDrag` on a tab never started.
struct TabPill: View {
    let title: String
    var dot: Color? = nil
    var icon: String? = nil
    /// The smaller size of a folder's second row.
    var compact = false
    let selected: Bool
    /// Something is being dragged over the tab and would land in it.
    var dropTarget = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
            }
            if let dot {
                Circle().fill(dot).frame(width: compact ? 9 : 11, height: compact ? 9 : 11)
            }
            Text(title)
                .font(.system(size: compact ? 12.5 : 14, weight: selected ? .medium : .light))
                .lineLimit(1)
        }
        .foregroundStyle(selected || dropTarget ? Theme.chromeTextPrimary : Theme.chromeTextSecondary)
        .padding(.horizontal, compact ? 10 : 12)
        .frame(height: compact ? 26 : 30)
        .background(dropTarget ? Theme.selection.opacity(0.22) : (selected ? Theme.pillSelected : Theme.pillBG),
                    in: Capsule())
        .overlay {
            if dropTarget { Capsule().strokeBorder(Theme.selection, lineWidth: 1.5) }
        }
        .scaleEffect(dropTarget ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dropTarget)
        .contentShape(Capsule())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, action)
        .fixedSize()
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

/// The tab being dragged, shared by both rows so a pinboard can be dragged
/// between the top row and a folder's row.
@MainActor
enum TabDrag {
    private static var dragged: BarSource?

    /// Marks a drag as a tab, told apart from a dragged card: a cancelled
    /// drag leaves `dragged` set, so that alone cannot tell.
    private static let typeIdentifier = "ch.claudeflaig.pastely.tab"

    static func begin(_ tab: BarSource) -> NSItemProvider {
        dragged = tab
        ClipDragProvider.clearDraggedItem()
        let provider = NSItemProvider(object: (TabOrder.key(tab) ?? "tab") as NSString)
        provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
            completion(Data(), nil)
            return nil
        }
        return provider
    }

    /// The dragged tab, if this drop is a tab drag, consumed.
    static func take(_ providers: [NSItemProvider]) -> BarSource? {
        let isTabDrag = providers.contains { $0.registeredTypeIdentifiers.contains(typeIdentifier) }
            // In case the mark gets lost on the way: a card drag always
            // leaves its clip behind, a tab drag clears it.
            || (dragged != nil && ClipDragProvider.recentlyDraggedItem == nil)
        guard isTabDrag, let tab = dragged else { return nil }
        dragged = nil
        return tab
    }

    static func targetBinding(_ target: Binding<BarSource?>, _ tab: BarSource) -> Binding<Bool> {
        Binding(
            get: { target.wrappedValue == tab },
            set: { target.wrappedValue = $0 ? tab : (target.wrappedValue == tab ? nil : target.wrappedValue) }
        )
    }
}

/// Pinboard actions both tab rows offer.
@MainActor
enum PinboardActions {
    private static var store: ClipboardStore { .shared }

    static func addPinboard(in groupID: UUID? = nil) {
        let board = store.addPinboard(name: "New Pinboard")
        if let groupID { store.movePinboard(board.id, into: groupID) }
        store.source = .pinboard(board.id); store.selectFirst()
    }

    static func addGroup() {
        guard let name = TextPrompt.run(title: "New Pinboard Folder",
                                        message: "Name the folder. Drop pinboard tabs on it to fill it.",
                                        defaultValue: "New Folder") else { return }
        let group = store.addGroup(name: name)
        store.source = .group(group.id); store.selectFirst()
    }

    static func rename(_ board: Pinboard) {
        if let name = TextPrompt.run(title: "Rename Pinboard", message: "Enter a new name",
                                     defaultValue: board.name) {
            store.renamePinboard(board.id, to: name)
        }
    }

    static func rename(_ group: PinboardGroup) {
        if let name = TextPrompt.run(title: "Rename Folder", message: "Enter a new name",
                                     defaultValue: group.name) {
            store.renameGroup(group.id, to: name)
        }
    }

    /// Dropping a card on a pinboard tab saves it there, as in Paste.
    static func saveDraggedCard(on tab: BarSource) -> Bool {
        guard case .pinboard(let boardID) = tab,
              let item = ClipDragProvider.recentlyDraggedItem else { return false }
        ClipDragProvider.clearDraggedItem()
        store.saveToPinboard(item, boardID: boardID)
        return true
    }

    @ViewBuilder
    static func folderMenu(for board: Pinboard) -> some View {
        Menu("Move to Folder") {
            ForEach(store.groups) { group in
                Button(group.name) { store.movePinboard(board.id, into: group.id) }
                    .disabled(board.groupID == group.id)
            }
            if !store.groups.isEmpty { Divider() }
            Button("New Folder…") {
                guard let name = TextPrompt.run(title: "New Pinboard Folder", message: "Name the folder.",
                                                defaultValue: "New Folder") else { return }
                let group = store.addGroup(name: name)
                store.movePinboard(board.id, into: group.id)
                store.source = .pinboard(board.id)
            }
        }
        if board.groupID != nil {
            Button("Remove from Folder") { store.removeFromGroup(board.id) }
        }
    }

    @ViewBuilder
    static func colorMenu(for board: Pinboard) -> some View {
        Menu("Color") {
            ForEach(ClipboardStore.pinboardColors, id: \.self) { hex in
                Button {
                    store.recolorPinboard(board.id, to: hex)
                } label: {
                    Label {
                        Text(colorName(hex))
                    } icon: {
                        Image(nsImage: dot(hex))
                    }
                }
            }
        }
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
