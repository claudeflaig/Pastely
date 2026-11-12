import SwiftUI

/// The bar's filters in a row of their own under the tabs: every clip type
/// as a chip to click, and the source app and date as menus. It shows while
/// searching, while a filter is on, or after the Filter button is clicked.
struct FilterBar: View {
    @Bindable private var store = ClipboardStore.shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ClipKind.allCases) { kind in
                let on = store.filter.kinds.contains(kind)
                FilterChip(title: kind.title, symbol: kind.symbol, active: on) {
                    if on { store.filter.kinds.remove(kind) } else { store.filter.kinds.insert(kind) }
                }
                .help(on ? "Show every type again" : "Show only \(kind.title.lowercased()) clips")
            }

            Rectangle()
                .fill(Theme.chromeTextTertiary.opacity(0.5))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)

            appMenu
            dateMenu

            Spacer(minLength: 8)

            if store.filter.isActive || !store.searchText.isEmpty {
                Text(resultCount)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.chromeTextTertiary)
                    .lineLimit(1)
            }
            if store.filter.isActive {
                Button {
                    store.filter = ClipFilter()
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .buttonStyle(ChromePillButtonStyle())
                .help("Remove every filter")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 38)
        .animation(.easeOut(duration: 0.15), value: store.filter)
    }

    private var resultCount: String {
        let n = store.visibleItems.count
        return n == 1 ? "1 clip" : "\(n) clips"
    }

    private var appMenu: some View {
        Menu {
            Button("Any App") {
                store.filter.appBundleID = nil
                store.filter.appName = nil
            }
            .disabled(store.filter.appBundleID == nil)
            Divider()
            ForEach(appChoices, id: \.bundleID) { app in
                Toggle(isOn: Binding(
                    get: { store.filter.appBundleID == app.bundleID },
                    set: { on in
                        store.filter.appBundleID = on ? app.bundleID : nil
                        store.filter.appName = on ? app.name : nil
                    }
                )) {
                    Label {
                        Text(app.name)
                    } icon: {
                        Image(nsImage: AppIconProvider.icon(forBundleID: app.bundleID))
                    }
                }
            }
        } label: {
            if let id = store.filter.appBundleID {
                FilterChipLabel(title: store.filter.appName ?? id, icon: AppIconProvider.icon(forBundleID: id),
                                active: true, menu: true)
            } else {
                FilterChipLabel(title: "App", symbol: "app.dashed", active: false, menu: true)
            }
        }
        // The button style keeps the label's capsule, which a borderless
        // menu would draw as plain text.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Show only clips from one app")
    }

    private var dateMenu: some View {
        Menu {
            Button("Any Time") { store.filter.dateRange = nil }
                .disabled(store.filter.dateRange == nil)
            Divider()
            ForEach(ClipDateRange.allCases) { range in
                Toggle(range.title, isOn: Binding(
                    get: { store.filter.dateRange == range },
                    set: { store.filter.dateRange = $0 ? range : nil }
                ))
            }
        } label: {
            FilterChipLabel(title: store.filter.dateRange?.title ?? "Any Time", symbol: "calendar",
                            active: store.filter.dateRange != nil, menu: true)
        }
        // The button style keeps the label's capsule, which a borderless
        // menu would draw as plain text.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Show only recent clips")
    }

    /// Apps found in the source being searched, so every choice has results.
    private var appChoices: [(bundleID: String, name: String)] {
        ClipFilter.apps(in: store.items(in: store.source))
    }
}

/// One filter you click on and off.
private struct FilterChip: View {
    let title: String
    let symbol: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FilterChipLabel(title: title, symbol: symbol, active: active, menu: false)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// A capsule: quiet when off, filled with the selection blue when on.
struct FilterChipLabel: View {
    let title: String
    var symbol: String? = nil
    var icon: NSImage? = nil
    let active: Bool
    let menu: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 15, height: 15)
            } else if let symbol {
                Image(systemName: symbol).font(.system(size: 11, weight: .medium))
            }
            Text(title)
                .font(.system(size: 12, weight: active ? .semibold : .medium))
                .lineLimit(1)
            if menu {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.7)
            }
        }
        .foregroundStyle(active ? Color.white : Theme.chromeTextSecondary)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background {
            Capsule().fill(active ? AnyShapeStyle(Theme.selection.gradient)
                                  : AnyShapeStyle(hovering ? Theme.pillHover : Theme.pillSelected))
        }
        .overlay {
            Capsule().strokeBorder(active ? Color.white.opacity(0.22) : Theme.cardBorder, lineWidth: 0.5)
        }
        .shadow(color: active ? Theme.selection.opacity(0.35) : .clear, radius: 4, y: 1)
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .fixedSize()
    }
}

/// Always in the top bar: opens the filter row, and counts the filters on.
struct FilterButton: View {
    @Bindable private var store = ClipboardStore.shared
    let shown: Bool

    private var activeCount: Int {
        store.filter.kinds.count + (store.filter.appBundleID != nil ? 1 : 0) + (store.filter.dateRange != nil ? 1 : 0)
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { store.showsFilterBar.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .semibold))
                Text("Filter")
                    .font(.system(size: 13, weight: .medium))
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 10.5, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Theme.selection, in: Capsule())
                }
            }
            .foregroundStyle(shown || activeCount > 0 ? Theme.selection : Theme.chromeTextSecondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(shown ? Theme.selection.opacity(0.14) : Theme.pillSelected))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(shown ? "Hide filters" : "Filter by type, app or date")
        .accessibilityLabel("Filters")
    }
}
