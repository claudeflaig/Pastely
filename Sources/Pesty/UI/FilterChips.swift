import SwiftUI

/// Paste's filter chips: a menu to add a type, app or date filter, and one
/// removable chip per active filter, sitting inside the search field.
struct FilterChips: View {
    @Bindable private var store = ClipboardStore.shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(store.filter.kinds).sorted { $0.rawValue < $1.rawValue }) { kind in
                chip(kind.title, symbol: kind.symbol) { store.filter.kinds.remove(kind) }
            }
            if let name = store.filter.appName ?? store.filter.appBundleID {
                chip(name, symbol: "app") {
                    store.filter.appBundleID = nil
                    store.filter.appName = nil
                }
            }
            if let range = store.filter.dateRange {
                chip(range.title, symbol: "calendar") { store.filter.dateRange = nil }
            }
            addMenu
        }
        .fixedSize()
    }

    private func chip(_ title: String, symbol: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(title) filter")
        }
        .foregroundStyle(.white)
        .padding(.leading, 8)
        .padding(.trailing, 7)
        .frame(height: 22)
        .background(Theme.selection, in: Capsule())
    }

    private var addMenu: some View {
        Menu {
            Section("Type") {
                ForEach(ClipKind.allCases) { kind in
                    Toggle(isOn: Binding(
                        get: { store.filter.kinds.contains(kind) },
                        set: { on in
                            if on { store.filter.kinds.insert(kind) } else { store.filter.kinds.remove(kind) }
                        }
                    )) {
                        Label(kind.title, systemImage: kind.symbol)
                    }
                }
            }
            Section("App") {
                ForEach(appChoices, id: \.bundleID) { app in
                    Toggle(isOn: Binding(
                        get: { store.filter.appBundleID == app.bundleID },
                        set: { on in
                            store.filter.appBundleID = on ? app.bundleID : nil
                            store.filter.appName = on ? app.name : nil
                        }
                    )) {
                        Text(app.name)
                    }
                }
            }
            Section("Date") {
                ForEach(ClipDateRange.allCases) { range in
                    Toggle(range.title, isOn: Binding(
                        get: { store.filter.dateRange == range },
                        set: { store.filter.dateRange = $0 ? range : nil }
                    ))
                }
            }
            if store.filter.isActive {
                Divider()
                Button("Clear Filters") { store.filter = ClipFilter() }
            }
        } label: {
            Image(systemName: store.filter.isActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(store.filter.isActive ? Theme.selection : Theme.chromeTextSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Filter by type, app or date")
    }

    /// Apps found in the source being searched, so every choice has results.
    private var appChoices: [(bundleID: String, name: String)] {
        let base: [ClipItem]
        switch store.source {
        case .history: base = store.history
        case .pinboard(let id): base = store.pinboards.first { $0.id == id }?.items ?? []
        case .cleanShot: base = CleanShotLibrary.shared.items
        }
        return ClipFilter.apps(in: base)
    }
}
