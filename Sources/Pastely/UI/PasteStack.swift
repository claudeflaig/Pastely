import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

/// Paste's Paste Stack: ⇧⌘C opens a temporary stack, everything copied while
/// it is open joins it, and each ⌘V pastes the next item in order.
///
/// The stack keeps its next item on the pasteboard. A copy is captured as
/// usual and then the pasteboard is put back to the next item, so the first
/// ⌘V pastes the first thing copied. A global key monitor notices each ⌘V in
/// another app and stages the following item once that app has read the
/// pasteboard. Watching other apps' keys needs the Accessibility permission,
/// which direct paste already asks for.
@Observable
@MainActor
final class PasteStack {
    static let shared = PasteStack()

    private(set) var isActive = false
    private(set) var queue = PasteStackQueue()
    /// True when ⌘V presses cannot be observed, so the panel can say why the
    /// stack does not advance.
    private(set) var needsAccessibility = false

    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private lazy var panel = PasteStackPanelController()

    /// How long the frontmost app gets to read the pasteboard before the next
    /// item replaces it.
    private static let advanceDelay: TimeInterval = 0.25

    private init() {}

    func toggle() {
        isActive ? close() : open()
    }

    func open() {
        guard !isActive else { return }
        isActive = true
        queue = PasteStackQueue()
        needsAccessibility = !AXIsProcessTrusted()
        startKeyMonitor()
        panel.show()
    }

    func close() {
        guard isActive else { return }
        isActive = false
        queue.clear()
        stopKeyMonitor()
        panel.hide()
    }

    /// Called for every clip the clipboard monitor records.
    func capture(_ item: ClipItem) {
        guard isActive else { return }
        queue.add(item)
        stageNext()
    }

    func remove(_ item: ClipItem) {
        queue.remove(id: item.id)
        stageNext()
    }

    func reverse() {
        queue.reversed.toggle()
        stageNext()
    }

    /// Puts the clip the next ⌘V should paste on the pasteboard, without the
    /// monitor recording that write as a new copy.
    private func stageNext() {
        guard let next = queue.next else { return }
        let change = PasteService.copy(next)
        AppController.shared.monitor.suppressUntilChangeCount = change
    }

    private func advanceAfterPaste() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.advanceDelay) { [weak self] in
            guard let self, self.isActive, !self.queue.isEmpty else { return }
            self.queue.popNext()
            self.stageNext()
        }
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == UInt16(kVK_ANSI_V),
                  flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option),
                  !event.isARepeat else { return }
            MainActor.assumeIsolated { PasteStack.shared.advanceAfterPaste() }
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}

/// A small floating bar that shows the stack without taking focus from the
/// app being pasted into.
@MainActor
final class PasteStackPanelController {
    private static let size = NSSize(width: 640, height: 214)
    private static let margin: CGFloat = 18

    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: PasteStackView())
        return panel
    }()

    func show() {
        panel.appearance = Settings.shared.barAppearance.nsAppearance
        panel.sharingType = Settings.shared.hideWhileScreenSharing ? .none : .readOnly
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            // Same edge as the bar, centered, so it reads as part of Pastely.
            let y = Settings.shared.barEdge == .top
                ? vf.maxY - Self.size.height - Self.margin
                : vf.minY + Self.margin
            panel.setFrameOrigin(NSPoint(x: vf.midX - Self.size.width / 2, y: y))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            DispatchQueue.main.async { panel.orderOut(nil) }
        })
    }
}

struct PasteStackView: View {
    @Bindable private var stack = PasteStack.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if stack.queue.isEmpty {
                emptyState
            } else {
                cards
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                VisualEffectView(material: .popover)
                Theme.panelTint
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.cardBorder)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.selection)
            Text("Paste Stack")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.chromeTextPrimary)
            Text(stack.queue.count == 1 ? "1 item" : "\(stack.queue.count) items")
                .font(.system(size: 12))
                .foregroundStyle(Theme.chromeTextSecondary)
            Spacer(minLength: 8)
            if stack.needsAccessibility {
                Label("Allow Accessibility to paste in order", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
            Button {
                stack.reverse()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(stack.queue.reversed ? Theme.selection : Theme.chromeTextSecondary)
                    .frame(width: 26, height: 26)
                    .background(stack.queue.reversed ? Theme.pillSelected : Color.clear, in: Circle())
            }
            .buttonStyle(.plain)
            .help(stack.queue.reversed ? "Pasting newest first" : "Pasting oldest first")
            .accessibilityLabel("Reverse paste order")
            Button {
                stack.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.chromeTextSecondary)
                    .frame(width: 26, height: 26)
                    .background(Theme.fieldBG, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close Paste Stack (\(Settings.shared.pasteStackHotkeyDisplay))")
            .accessibilityLabel("Close Paste Stack")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.chromeTextTertiary)
            Text("Copy items to add them to the stack.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.chromeTextSecondary)
            Text("Each ⌘V then pastes the next one in order.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.chromeTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cards: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(stack.queue.pasteOrder.enumerated()), id: \.element.id) { index, item in
                        PasteStackCard(item: item, position: index + 1, isNext: index == 0)
                            .id(item.id)
                            .contextMenu {
                                Button(role: .destructive) {
                                    stack.remove(item)
                                } label: {
                                    Label("Remove from Stack", systemImage: "minus.circle")
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: stack.queue.pasteOrder.map(\.id))
            }
            .onChange(of: stack.queue.pasteOrder.first?.id) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .leading) }
            }
        }
    }
}

/// A compact card in Paste's style: the source app's color and a numbered
/// badge for the paste order, with the next card ringed in blue.
private struct PasteStackCard: View {
    let item: ClipItem
    let position: Int
    let isNext: Bool

    private static let width: CGFloat = 132
    private static let corner: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                SourceColor.color(for: item.sourceBundleID)
                HStack(spacing: 6) {
                    Text("\(position)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SourceColor.color(for: item.sourceBundleID))
                        .frame(width: 18, height: 18)
                        .background(.white, in: Circle())
                    Text(ClipKind.of(item).title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.headerText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(nsImage: AppIconProvider.icon(forBundleID: item.sourceBundleID))
                        .resizable().interpolation(.high)
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 32)
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.cardBody)
        }
        .frame(width: Self.width, height: 136)
        .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .strokeBorder(isNext ? Theme.selection : Theme.cardBorder, lineWidth: isNext ? 3 : 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.type {
        case .color:
            ZStack {
                Color(hex: item.colorHex ?? "#000") ?? .black
                Text((item.colorHex ?? "").uppercased())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
        case .image:
            if let image = ClipboardStore.shared.loadImage(for: item) {
                Image(nsImage: image).resizable().scaledToFill().clipped()
            } else {
                symbol("photo")
            }
        case .file:
            Text(item.displayTitle)
                .font(.system(size: 11))
                .foregroundStyle(Theme.cardTextSecondary)
                .lineLimit(4)
                .multilineTextAlignment(.center)
                .padding(8)
        default:
            Text(item.text ?? "")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.cardTextPrimary)
                .lineLimit(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 22, weight: .light))
            .foregroundStyle(Theme.cardTextTertiary)
    }
}
