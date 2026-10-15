import SwiftUI
import AppKit

/// The sections of the Settings window, listed in its sidebar the way System
/// Settings lists its panes: a colored icon tile and a name.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, shortcuts, pasteStack, shelf, history, privacy, sync, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .shortcuts: "Shortcuts"
        case .pasteStack: "Paste Stack"
        case .shelf: "Shelf"
        case .history: "History"
        case .privacy: "Privacy"
        case .sync: "Sync"
        case .about: "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "How Pastely starts and behaves when you paste."
        case .appearance: "Theme, position and what the cards show."
        case .shortcuts: "Keyboard shortcuts for the bar and quick paste."
        case .pasteStack: "Collect several copies, then paste them in order."
        case .shelf: "A small window that holds new copies and files until you drag them somewhere."
        case .history: "How long clips are kept, and the data on this Mac."
        case .privacy: "Apps and content Pastely never records."
        case .sync: "Keep history and pinboards in step across your Macs."
        case .about: "Version, source code and credits."
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .shortcuts: "keyboard.fill"
        case .pasteStack: "square.stack.3d.up.fill"
        case .shelf: "tray.full.fill"
        case .history: "clock.fill"
        case .privacy: "hand.raised.fill"
        case .sync: "icloud.fill"
        case .about: "info.circle.fill"
        }
    }

    /// `--demo-settings=<pane>` opens Settings on that pane, so each one can
    /// be looked at without clicking through.
    static var initial: SettingsPane {
        let arg = CommandLine.arguments.first { $0.hasPrefix("--demo-settings=") }
        return arg.flatMap { SettingsPane(rawValue: String($0.dropFirst("--demo-settings=".count))) } ?? .general
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .appearance: .pink
        case .shortcuts: .indigo
        case .pasteStack: .blue
        case .shelf: .teal
        case .history: .orange
        case .privacy: .green
        case .sync: .cyan
        case .about: .purple
        }
    }
}

struct SettingsView: View {
    @State private var pane: SettingsPane = SettingsPane.initial



    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { pane in
                HStack(spacing: 10) {
                    SettingsIcon(symbol: pane.symbol, tint: pane.tint, size: 24)
                    Text(pane.title).font(.system(size: 13.5))
                }
                .padding(.vertical, 5)
                .padding(.leading, 2)
                .tag(pane)
            }
            .listStyle(.sidebar)
            .environment(\.defaultMinListRowHeight, 38)
            .navigationSplitViewColumnWidth(min: 210, ideal: 220, max: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsHeader(pane: pane)
                    paneContent
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(pane.title)
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch pane {
        case .general: GeneralSettings()
        case .appearance: AppearanceSettings()
        case .shortcuts: ShortcutSettings()
        case .pasteStack: PasteStackSettings()
        case .shelf: ShelfSettings()
        case .history: HistorySettings()
        case .privacy: PrivacySettings()
        case .sync: SyncSettings()
        case .about: AboutView()
        }
    }
}

// MARK: - Building blocks

/// A white SF Symbol on a rounded, gradient-filled tile, as in System Settings.
struct SettingsIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

private struct SettingsHeader: View {
    let pane: SettingsPane

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(symbol: pane.symbol, tint: pane.tint, size: 44)
                .shadow(color: pane.tint.opacity(0.35), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title)
                    .font(.system(size: 22, weight: .bold))
                Text(pane.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}

/// A rounded card holding rows, separated by hairlines.
struct SettingsCard<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            rows
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            if let footer {
                Text(footer)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension SettingsCard {
    /// Hairlines between rows where the OS can enumerate a view's children;
    /// macOS 14 stacks the rows with spacing instead.
    @ViewBuilder
    fileprivate var rows: some View {
        let stack = VStack(alignment: .leading, spacing: 0) {
            if #available(macOS 15.0, *) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().padding(.leading, 14) }
                        row
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        stack
    }
}

/// A row with a title, an optional explanation and a trailing control.
struct SettingsRow<Accessory: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
    }
}

struct SettingsToggle: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title, detail: detail) {
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

/// A picture-led choice, like the appearance tiles in System Settings.
private struct ChoiceTile<Preview: View>: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var preview: Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                preview
                    .frame(width: 118, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12),
                                          lineWidth: selected ? 3 : 1)
                    )
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A miniature desktop with the card bar on it, for the theme and position
/// tiles.
private struct BarMiniature: View {
    var dark: Bool
    var split = false
    var top = false

    private let cardColors: [Color] = [.yellow, .blue, .pink, .green]

    var body: some View {
        ZStack(alignment: top ? .top : .bottom) {
            LinearGradient(colors: [Color(red: 0.36, green: 0.55, blue: 0.95), Color(red: 0.62, green: 0.42, blue: 0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(spacing: 0) {
                bar(dark: split ? false : dark)
                if split { bar(dark: true) }
            }
            .frame(height: 30)
        }
    }

    private func bar(dark: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(cardColors.indices, id: \.self) { i in
                VStack(spacing: 0) {
                    cardColors[i].frame(height: 5)
                    (dark ? Color(white: 0.2) : .white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .frame(width: 18, height: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dark ? Color.black.opacity(0.55) : Color.white.opacity(0.6))
    }
}

// MARK: - Panes

private struct GeneralSettings: View {
    @Bindable private var settings = Settings.shared
    #if !MAS
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var requestedGrant = false

    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            #if !MAS
            SettingsCard(title: "Permissions") {
                HStack(spacing: 12) {
                    Image(systemName: accessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility").font(.system(size: 13, weight: .medium))
                        Text(accessibilityGranted
                             ? "Granted. Pastely can paste directly and advance the Paste Stack."
                             : (requestedGrant
                                ? "Waiting… switch Pastely on in System Settings."
                                : "Needed to paste directly into other apps and for the Paste Stack."))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !accessibilityGranted {
                        Button("Open Settings") {
                            requestedGrant = true
                            PasteService.ensureAccessibility(prompt: true)
                            openAccessibilityPane()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else if requestedGrant {
                        Button("Restart Pastely") { AppController.restart() }
                            .controlSize(.small)
                    }
                }
            }
            #endif

            SettingsCard(title: "Startup") {
                SettingsToggle(title: "Launch at login", isOn: $settings.launchAtLogin)
                SettingsToggle(title: "Show Pastely in the menu bar", isOn: $settings.showMenuBarIcon)
            }

            SettingsCard(title: "Pasting") {
                #if !MAS
                SettingsToggle(title: "Paste directly into the active app",
                               detail: "Otherwise the clip is copied and you press ⌘V yourself.",
                               isOn: $settings.pasteDirectly)
                #endif
                SettingsToggle(title: "Move pasted clips to the front", isOn: $settings.promoteOnPaste)
                SettingsToggle(title: "Hide the bar when clicking outside", isOn: $settings.hideOnClickOutside)
                SettingsRow(title: "Reopen on the last tab",
                            detail: "After this long the bar opens on Clipboard again.") {
                    Picker("", selection: $settings.tabMemory) {
                        ForEach(TabMemory.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsToggle(title: "Play a sound when a copy reaches Pastely", isOn: $settings.playSoundOnCapture)
                SettingsRow(title: "Sound") {
                    Picker("", selection: $settings.captureSoundName) {
                        ForEach(Settings.captureSoundChoices, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!settings.playSoundOnCapture)
                    .onChange(of: settings.captureSoundName) { _, name in
                        ClipboardMonitor.playCaptureSound(named: name)
                    }
                }
                SettingsToggle(title: "Play a sound when pasting", isOn: $settings.playSound)
                SettingsToggle(title: "Play a sound when copying from Pastely", isOn: $settings.playSoundOnCopy)
                #if MAS
                Text("Select a clip to copy it, then press ⌘V to paste it into your app.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                #endif
            }
        }
        #if !MAS
        .onAppear { accessibilityGranted = AXIsProcessTrusted() }
        .onReceive(poll) { _ in
            let now = AXIsProcessTrusted()
            if now != accessibilityGranted { accessibilityGranted = now }
        }
        #endif
    }

    #if !MAS
    private func openAccessibilityPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    #endif
}

private struct AppearanceSettings: View {
    @Bindable private var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "Theme") {
                HStack(spacing: 14) {
                    ForEach(BarAppearance.allCases) { appearance in
                        ChoiceTile(title: appearance.title, selected: settings.barAppearance == appearance) {
                            settings.barAppearance = appearance
                        } preview: {
                            BarMiniature(dark: appearance == .dark, split: appearance == .system)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            SettingsCard(title: "Position") {
                HStack(spacing: 14) {
                    ForEach(BarEdge.allCases) { edge in
                        ChoiceTile(title: edge.title, selected: settings.barEdge == edge) {
                            settings.barEdge = edge
                        } preview: {
                            BarMiniature(dark: false, top: edge == .top)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Bar height").font(.system(size: 13))
                        Spacer()
                        Text("\(Int(settings.barHeight)) pt")
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    // Rounded in the binding rather than with `step`, which
                    // would draw a tick mark for every 10 pt.
                    Slider(value: Binding(
                        get: { settings.barHeight },
                        set: { settings.barHeight = ($0 / 10).rounded() * 10 }
                    ), in: 300...720)
                }
                SettingsToggle(title: "Show a resize handle on the bar", isOn: $settings.showBarResizeHandle)
                SettingsRow(title: "Selected card", detail: settings.selectedClipPosition.detail) {
                    Picker("", selection: $settings.selectedClipPosition) {
                        ForEach(SelectedClipPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsCard(title: "Card Colors", footer: settings.clipColorTheme.detail) {
                Picker("", selection: $settings.clipColorTheme) {
                    ForEach(ClipColorTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                if settings.clipColorTheme == .accentShades {
                    SettingsRow(title: "Base color") {
                        HStack(spacing: 4) {
                            ForEach(Array(SourceColor.accentShades(for: settings.clipColorAccentHex).enumerated()),
                                    id: \.offset) { _, color in
                                Circle().fill(color).frame(width: 12, height: 12)
                            }
                            .accessibilityLabel("Ten stable shades of the selected base color")
                            ColorPicker("", selection: clipColorAccent, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                }
            }

            SettingsCard(title: "Folders as Pinboards",
                         footer: "Each folder gets its own tab listing its newest files, ready to paste or drag. You can also add one with the + next to the tabs.") {
                ForEach(settings.pinnedFolders, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable().frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(FolderLibrary.title(for: path)).font(.system(size: 13))
                            Text((path as NSString).abbreviatingWithTildeInPath)
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            FolderLibrary.shared.remove(path)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Stop showing this folder")
                    }
                }
                Button { FolderLibrary.shared.chooseAndAdd() } label: { Label("Add Folder…", systemImage: "plus") }
                    .controlSize(.small)
            }

            SettingsCard(title: "Content",
                         footer: "Link previews load the page's title and image from the site the first time a link is shown.") {
                SettingsToggle(title: "Show link previews", isOn: $settings.linkPreviews)
                #if !MAS
                SettingsToggle(title: "Show CleanShot X history as a pinboard",
                               detail: "Your captures appear in their own tab, newest first.",
                               isOn: $settings.showCleanShotHistory)
                #endif
            }
        }
    }

    private var clipColorAccent: Binding<Color> {
        Binding(
            get: { Color(hex: settings.clipColorAccentHex) ?? .pink },
            set: { settings.clipColorAccentHex = NSColor($0).hexString }
        )
    }
}

private struct ShelfSettings: View {
    @Bindable private var settings = Settings.shared
    @Bindable private var shelf = Shelf.shared.model

    private static let kinds: [(type: ClipType, title: String)] = [
        (.text, "Text"), (.link, "Links"), (.image, "Images"), (.file, "Files"), (.color, "Colors")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "What goes on the Shelf",
                         footer: "The Shelf appears with the first item and stays until you close it or drag everything out.") {
                SettingsToggle(title: "Copies from your other devices",
                               detail: "What you copy on your iPhone, iPad or another Mac and arrives here through Continuity, whatever its kind.",
                               isOn: $settings.shelfForOtherDevices)
                SettingsToggle(title: "Copies on this Mac", isOn: $settings.shelfForClips)
                ForEach(Self.kinds, id: \.type) { kind in
                    SettingsToggle(title: kind.title, isOn: kindBinding(kind.type))
                        .padding(.leading, 18)
                        .disabled(!settings.shelfForClips)
                        .opacity(settings.shelfForClips ? 1 : 0.5)
                }
            }

            SettingsCard(title: "Watched folders",
                         footer: "Each file that lands in one of these folders, such as a finished download, goes on the Shelf. Hidden files and downloads still in progress are skipped.") {
                SettingsToggle(title: "New files in watched folders", isOn: $settings.shelfForFolders)
                ForEach(settings.shelfWatchedFolders, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable().frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(FolderLibrary.title(for: path)).font(.system(size: 13))
                            Text((path as NSString).abbreviatingWithTildeInPath)
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            settings.shelfWatchedFolders.removeAll { $0 == path }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Stop watching this folder")
                    }
                    .padding(.vertical, 2)
                    .disabled(!settings.shelfForFolders)
                    .opacity(settings.shelfForFolders ? 1 : 0.5)
                }
                HStack(spacing: 10) {
                    Button { FolderLibrary.shared.chooseWatchedFolders() } label: {
                        Label("Add Folder…", systemImage: "plus")
                    }
                    let tabFolders = settings.pinnedFolders.filter { !settings.shelfWatchedFolders.contains($0) }
                    if !tabFolders.isEmpty {
                        Menu("Add a Folder Tab") {
                            ForEach(tabFolders, id: \.self) { path in
                                Button(FolderLibrary.title(for: path)) { settings.shelfWatchedFolders.append(path) }
                            }
                        }
                        .fixedSize()
                    }
                }
                .controlSize(.small)
                .disabled(!settings.shelfForFolders)
            }

            SettingsCard(title: "Dragging out") {
                SettingsToggle(title: "Remove items once they are dropped",
                               detail: "Otherwise they stay on the Shelf until you close it.",
                               isOn: $settings.shelfRemoveAfterDrag)
                SettingsToggle(title: "Drop text in Finder as a file",
                               detail: "Text becomes a .txt file named after its first line, rich text an .rtf file. Text fields still get the text itself.",
                               isOn: $settings.shelfTextAsFile)
            }

            SettingsCard(title: "Window",
                         footer: "Drag the Shelf by any empty spot; it opens where you left it.") {
                SettingsRow(title: "Items on the Shelf now",
                            detail: shelf.items.isEmpty ? "The Shelf is empty." : ShelfModel.title(for: shelf.items)) {
                    Button("Close Shelf") { Shelf.shared.clear() }
                        .controlSize(.small)
                        .disabled(shelf.items.isEmpty)
                }
                SettingsRow(title: "Position") {
                    Button("Move to Lower Right") { Shelf.shared.resetPosition() }
                        .controlSize(.small)
                }
            }
        }
    }

    private func kindBinding(_ type: ClipType) -> Binding<Bool> {
        Binding(
            get: { settings.shelfKinds.contains(type.rawValue) },
            set: { on in
                if on { settings.shelfKinds.insert(type.rawValue) } else { settings.shelfKinds.remove(type.rawValue) }
            }
        )
    }
}

private struct ShortcutSettings: View {
    @Bindable private var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "Global Shortcuts", footer: "Click a shortcut, then press the new key combination.") {
                SettingsRow(title: "Show Pastely") {
                    HotkeyRecorderView(keyCode: $settings.hotkeyKeyCode,
                                       modifiers: $settings.hotkeyModifiers,
                                       reserved: [(settings.pasteStackKeyCode, settings.pasteStackModifiers), (settings.plainTextPasteKeyCode, settings.plainTextPasteModifiers)])
                }
                SettingsRow(title: "Open or close the Paste Stack") {
                    HotkeyRecorderView(keyCode: $settings.pasteStackKeyCode,
                                       modifiers: $settings.pasteStackModifiers,
                                       reserved: [(settings.hotkeyKeyCode, settings.hotkeyModifiers), (settings.plainTextPasteKeyCode, settings.plainTextPasteModifiers)])
                        .disabled(!settings.pasteStackShortcut)
                        .opacity(settings.pasteStackShortcut ? 1 : 0.5)
                }
            }

            #if !MAS
            SettingsCard(title: "Paste as Plain Text",
                         footer: "Pastes what is on the clipboard without fonts, colors or links, in any app. The clipboard keeps its formatting. Many apps use ⌥⇧⌘V for Paste and Match Style; while this is on, Pastely handles it everywhere. Needs the Accessibility permission.") {
                SettingsToggle(title: "Enable the plain text shortcut", isOn: $settings.plainTextPasteShortcut)
                SettingsRow(title: "Shortcut") {
                    HotkeyRecorderView(keyCode: $settings.plainTextPasteKeyCode,
                                       modifiers: $settings.plainTextPasteModifiers,
                                       reserved: [(settings.hotkeyKeyCode, settings.hotkeyModifiers), (settings.pasteStackKeyCode, settings.pasteStackModifiers)])
                        .disabled(!settings.plainTextPasteShortcut)
                        .opacity(settings.plainTextPasteShortcut ? 1 : 0.5)
                }
            }
            #endif

            #if !MAS
            SettingsCard(title: "Abbreviations",
                         footer: "Right-click a card in a pinboard and choose Set Abbreviation. Typing it anywhere replaces it with the clip; your clipboard is put back afterwards. Needs the Accessibility permission.") {
                SettingsToggle(title: "Expand abbreviations as you type", isOn: $settings.expandAbbreviations)
                let clips = ClipboardStore.shared.abbreviatedClips
                if clips.isEmpty {
                    Text("No abbreviations yet.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    ForEach(clips) { clip in
                        HStack(spacing: 10) {
                            Text(clip.abbreviation ?? "")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                            Text(clip.customTitle ?? clip.displayTitle)
                                .font(.system(size: 13)).lineLimit(1)
                            Spacer()
                            Button {
                                ClipboardStore.shared.setAbbreviation(nil, for: clip)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove this abbreviation")
                        }
                    }
                }
            }
            #endif

            SettingsCard(title: "Quick Paste",
                         footer: "Hold the plain-text modifier as well to strip formatting; with the defaults, ⌘⇧1 pastes the first clip as plain text. The two can never share a modifier; picking one that is taken swaps them.") {
                SettingsRow(title: "Paste items 1–9") {
                    HStack(spacing: 6) {
                        modifierPicker(selection: $settings.quickPasteModifier)
                        Text("+ 1…9").foregroundStyle(.secondary)
                    }
                }
                SettingsRow(title: "Paste as plain text") {
                    modifierPicker(selection: $settings.plainTextModifier)
                }
            }
        }
    }

    private func modifierPicker(selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(ShortcutModifier.allCases) { modifier in
                Text("\(modifier.symbol) \(modifier.title)").tag(modifier.carbonValue)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }
}

private struct PasteStackSettings: View {
    @Bindable private var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "How it works") {
                stepRow(1, "Press \(settings.pasteStackHotkeyDisplay) to open a stack.")
                stepRow(2, "Copy everything you need, in order. Copying an item again moves it to the end.")
                stepRow(3, "Each ⌘V pastes the next item. The arrows in the stack reverse the order.")
                stepRow(4, "Press \(settings.pasteStackHotkeyDisplay) again, or click ✕, to close it.")
            }
            SettingsCard(footer: "Pasting in order needs the Accessibility permission, so Pastely can notice each ⌘V. Some apps use ⇧⌘C themselves; change the shortcut under Shortcuts.") {
                SettingsToggle(title: "Enable the Paste Stack shortcut", isOn: $settings.pasteStackShortcut)
                SettingsRow(title: "Shortcut") {
                    HotkeyRecorderView(keyCode: $settings.pasteStackKeyCode,
                                       modifiers: $settings.pasteStackModifiers,
                                       reserved: [(settings.hotkeyKeyCode, settings.hotkeyModifiers), (settings.plainTextPasteKeyCode, settings.plainTextPasteModifiers)])
                        .disabled(!settings.pasteStackShortcut)
                        .opacity(settings.pasteStackShortcut ? 1 : 0.5)
                }
                SettingsRow(title: "Open a stack now") {
                    Button(PasteStack.shared.isActive ? "Close Stack" : "Open Stack") { PasteStack.shared.toggle() }
                        .controlSize(.small)
                }
            }
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue.gradient, in: Circle())
            Text(text).font(.system(size: 13))
        }
    }
}

private struct HistorySettings: View {
    @Bindable private var settings = Settings.shared
    @State private var confirmingClear = false
    @State private var importMessage: String?

    private func exportPinboards() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Pastely Pinboards.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ClipboardStore.shared.pinboardArchive().encoded().write(to: url, options: .atomic)
            importMessage = "Exported \(ClipboardStore.shared.pinboards.count) pinboards."
        } catch {
            importMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importFromPasty() {
        do {
            let result = try PastyImporter.importPinboards()
            importMessage = "Imported \(result.clips) clips into \(result.boards) pinboards from Pasty."
        } catch {
            importMessage = "Pasty's data could not be read: \(error.localizedDescription)"
        }
    }

    private func importPinboards() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let archive = try PinboardArchive.decode(Data(contentsOf: url))
            let added = ClipboardStore.shared.importPinboards(archive)
            importMessage = "Imported \(added) clips into \(archive.pinboards.count) pinboards."
        } catch {
            importMessage = "This file is not a Pastely pinboard export."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form { HistoryRetentionSettings() }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .frame(minHeight: settings.historyRetentionMode == .itemCount ? 190 : 260)
                .padding(.horizontal, -20)
                .padding(.vertical, -10)

            SettingsCard(title: "Pinboards",
                         footer: importMessage ?? "Save your pinboards as a file for safekeeping, or bring templates in from one.") {
                SettingsRow(title: "Export pinboards", detail: "Writes every pinboard and its clips to a JSON file.") {
                    Button("Export…") { exportPinboards() }.controlSize(.small)
                }
                SettingsRow(title: "Import pinboards", detail: "Boards with the same name are merged; duplicates are skipped.") {
                    Button("Import…") { importPinboards() }.controlSize(.small)
                }
                do {
                    SettingsRow(title: "Import from Pasty",
                                detail: "macOS asks once whether Pastely may read Pasty's data.") {
                        Button("Import…") { importFromPasty() }.controlSize(.small)
                    }
                }
            }

            SettingsCard(title: "Deleting") {
                SettingsToggle(title: "Delete permanently",
                               detail: "Skips the five-minute Undo window. Hold Option while deleting to skip it once.",
                               isOn: $settings.deletePermanently)
                SettingsRow(title: "Clear clipboard history", detail: "Pinboards are kept.") {
                    Button("Clear…", role: .destructive) { confirmingClear = true }
                        .controlSize(.small)
                }
            }
        }
        .alert("Clear Clipboard History?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { ClipboardStore.shared.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every clip in history is removed. Pinboards are not affected.")
        }
    }
}

private struct SyncSettings: View {
    @Bindable private var settings = Settings.shared

    var body: some View {
        #if MAS
        SettingsCard(footer: CloudSyncService.shared.status) {
            SettingsToggle(title: "Sync history with iCloud", isOn: Binding(
                get: { settings.cloudKitSync },
                set: { on in
                    settings.cloudKitSync = on
                    if on { CloudSyncService.shared.enable() } else { CloudSyncService.shared.stop() }
                }))
        }
        #else
        SettingsCard(footer: ClipboardStore.shared.iCloudAvailable
                     ? "Keeps your history and pinboards in sync across your Macs through iCloud Drive."
                     : "Sign in to iCloud and turn on iCloud Drive to use sync.") {
            SettingsToggle(title: "Sync through iCloud Drive", isOn: Binding(
                get: { settings.iCloudSync },
                set: { _ in AppController.shared.toggleICloudSync() }))
        }
        #endif
    }
}

private struct PrivacySettings: View {
    @Bindable private var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "Sensitive Content") {
                SettingsToggle(title: "Ignore passwords",
                               detail: "Skips content that password managers mark as concealed.",
                               isOn: $settings.ignoreConcealed)
                SettingsToggle(title: "Hide from screen sharing and recordings",
                               detail: "The bar and the Paste Stack stay invisible to others.",
                               isOn: $settings.hideWhileScreenSharing)
            }

            SettingsCard(title: "Excluded Apps",
                         footer: "Nothing copied while one of these apps is frontmost is saved. Copies from a browser extension count as the browser's, so add the browser too if you use one.") {
                if settings.ignoredSourceAppBundleIDs.isEmpty {
                    HStack {
                        Image(systemName: "hand.raised").foregroundStyle(.secondary)
                        Text("No apps excluded").foregroundStyle(.secondary)
                    }
                    .font(.system(size: 13))
                } else {
                    ForEach(settings.ignoredSourceAppBundleIDs, id: \.self) { bundleID in
                        ignoredAppRow(bundleID)
                    }
                }
                Button { chooseApps() } label: {
                    Label("Add App…", systemImage: "plus")
                }
                .controlSize(.small)
            }
        }
    }

    private func ignoredAppRow(_ bundleID: String) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIconProvider.icon(forBundleID: bundleID))
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(applicationName(for: bundleID))
                    .font(.system(size: 13, weight: .medium))
                Text(bundleID)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { settings.removeIgnoredSourceApp(bundleID) } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Allow clips from \(applicationName(for: bundleID))")
        }
        .padding(.vertical, 4)
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.title = "Exclude Apps from Pastely"
        panel.message = "Pastely will ignore copied content from the apps you choose."
        panel.prompt = "Add Apps"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier,
                  bundleID != Bundle.main.bundleIdentifier else { continue }
            settings.addIgnoredSourceApp(bundleID)
        }
    }

    private func applicationName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url) else { return bundleID }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? bundleID
    }
}

private struct HistoryRetentionSettings: View {
    private var settings = Settings.shared
    @State private var draftMode = Settings.shared.historyRetentionMode
    @State private var draftLimit = Settings.shared.historyLimit
    @State private var draftDays = Settings.shared.historyRetentionDays
    @State private var pendingRemovalCount = 0
    @State private var confirmingChange = false
    @State private var storageBytes: Int64?

    @State private var sliderValue = HistoryRetentionPreset(nearestDays: Settings.shared.historyRetentionDays).sliderIndex
    @State private var sliderEditing = false

    private var sliderPreset: HistoryRetentionPreset { HistoryRetentionPreset(sliderIndex: sliderValue) }

    private var storageSummary: String {
        let store = ClipboardStore.shared
        let count = store.history.count + store.pinboards.reduce(0) { $0 + $1.items.count }
        let clips = "\(count) clip\(count == 1 ? "" : "s")"
        guard let storageBytes else { return clips }
        return "\(clips) · \(ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file))"
    }

    private func refreshStorageSize() async {
        let dir = ClipboardStore.shared.dataDirectory
        storageBytes = await Task.detached(priority: .utility) {
            Self.directorySize(at: dir)
        }.value
    }

    /// Walks the store directory off the main actor; images can make it
    /// large enough that a synchronous walk would hitch the Settings window.
    nonisolated private static func directorySize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: url,
                                                              includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    var body: some View {
        Section {
            Picker("Limit history by", selection: $draftMode) {
                ForEach(HistoryRetentionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            if draftMode == .itemCount {
                Stepper(value: $draftLimit, in: 50...5000, step: 50) {
                    LabeledContent("Keep at most", value: "\(draftLimit) clips")
                }
            }
        } header: {
            Text("History")
        } footer: {
            // A grouped Form lays Section body rows out on a shared label/control
            // grid that clamps a bare Slider; the footer is plain full-width content.
            if draftMode != .itemCount {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("Remove clips older than")
                        Spacer()
                        Text(sliderPreset.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                    }
                    Slider(value: $sliderValue,
                           in: 0...Double(HistoryRetentionPreset.allCases.count - 1),
                           step: 1,
                           onEditingChanged: { editing in
                               sliderEditing = editing
                               if !editing { applySliderValue() }
                           })
                    HStack(spacing: 0) {
                        ForEach(HistoryRetentionPreset.allCases) { preset in
                            Text(preset.shortTitle)
                                .font(.system(size: 10, weight: preset == sliderPreset ? .bold : .medium))
                                .foregroundStyle(preset == sliderPreset ? Color.accentColor : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, draftMode == .itemCount ? 0 : 4)
            LabeledContent("History and pinboards on disk", value: storageSummary)
        }
        .task {
            await refreshStorageSize()
            for await _ in NotificationCenter.default.notifications(named: .pastelyStoreDidSave) {
                await refreshStorageSize()
            }
        }
        .onChange(of: draftMode) { evaluateDraft() }
        .onChange(of: draftLimit) { evaluateDraft() }
        .onChange(of: draftDays) { evaluateDraft() }
        .onChange(of: sliderValue) { if !sliderEditing { applySliderValue() } }
        .alert("Remove \(pendingRemovalCount) Clips?", isPresented: $confirmingChange) {
            Button("Remove \(pendingRemovalCount) Clips", role: .destructive) { commit() }
            Button("Cancel", role: .cancel) { revert() }
        } message: {
            Text("This setting removes \(pendingRemovalCount) clips from history on this Mac now, and keeps pruning automatically. Pinboards are not affected, and there is no undo.")
        }
    }

    private var footnote: String {
        #if MAS
        "Pruning tidies this Mac only — synced copies stay on your other devices. Pinned clips are never removed."
        #else
        "Pruning applies to this Mac's history. Pinned clips are never removed."
        #endif
    }

    private func evaluateDraft() {
        let count = ClipboardStore.shared.retentionRemovalCount(
            mode: draftMode, limit: draftLimit, days: draftDays)
        if count > 0 {
            pendingRemovalCount = count
            confirmingChange = true
        } else {
            commit()
        }
    }

    private func commit() {
        settings.historyRetentionMode = draftMode
        settings.historyLimit = draftLimit
        settings.historyRetentionDays = draftDays
        ClipboardStore.shared.applyRetentionPolicy()
    }

    private func revert() {
        draftMode = settings.historyRetentionMode
        draftLimit = settings.historyLimit
        draftDays = settings.historyRetentionDays
        sliderValue = HistoryRetentionPreset(nearestDays: draftDays).sliderIndex
    }

    private func applySliderValue() {
        let days = HistoryRetentionPreset(sliderIndex: sliderValue).days
        if days != draftDays { draftDays = days }
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable().frame(width: 88, height: 88)
            Text("Pastely").font(.system(size: 26, weight: .bold))
            Text("Version \(Bundle.main.appVersion)")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("A clipboard manager for macOS in the style of Paste.\nBased on Pesty by Moamen Basel.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/claudeflaig/Pastely")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/claudeflaig/Pastely/issues")!)
            }
            .padding(.top, 4)
            Button("Quit Pastely", role: .destructive) {
                NSApp.terminate(nil)
            }
            .padding(.top, 8)
            Spacer()
            Text("MIT Licensed · Made with SwiftUI")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
