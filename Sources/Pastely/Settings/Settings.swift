import AppKit
import Carbon.HIToolbox
import Observation

enum ShortcutModifier: CaseIterable, Identifiable {
    case command
    case option
    case control
    case shift

    var id: Int { carbonValue }

    var carbonValue: Int {
        switch self {
        case .command: return cmdKey
        case .option: return optionKey
        case .control: return controlKey
        case .shift: return shiftKey
        }
    }

    var title: String {
        switch self {
        case .command: return "Command"
        case .option: return "Option"
        case .control: return "Control"
        case .shift: return "Shift"
        }
    }

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    init?(carbonValue: Int) {
        guard let modifier = Self.allCases.first(where: { $0.carbonValue == carbonValue }) else {
            return nil
        }
        self = modifier
    }
}

enum HistoryRetentionMode: String, CaseIterable, Identifiable {
    case itemCount
    case timeInterval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .itemCount: return "Number of clips"
        case .timeInterval: return "Age of clips"
        }
    }
}

/// The discrete stops on the time-based retention slider. `historyRetentionDays`
/// stays the underlying source of truth (a raw day count, with 0 meaning
/// "forever" - never prune by age) - this just names the stops so the slider
/// can snap between them instead of offering a raw number field.
enum HistoryRetentionPreset: Int, CaseIterable, Identifiable {
    case day
    case week
    case twoWeeks
    case threeWeeks
    case month
    case twoMonths
    case threeMonths
    case sixMonths
    case year
    case forever

    var id: Int { rawValue }

    /// 0 means forever - no automatic time-based pruning.
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .twoWeeks: return 14
        case .threeWeeks: return 21
        case .month: return 30
        case .twoMonths: return 60
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        case .forever: return 0
        }
    }

    var title: String {
        switch self {
        case .day: return "1 Day"
        case .week: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .threeWeeks: return "3 Weeks"
        case .month: return "1 Month"
        case .twoMonths: return "2 Months"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .year: return "1 Year"
        case .forever: return "Forever"
        }
    }

    var shortTitle: String {
        switch self {
        case .day: return "1d"
        case .week: return "1w"
        case .twoWeeks: return "2w"
        case .threeWeeks: return "3w"
        case .month: return "1m"
        case .twoMonths: return "2m"
        case .threeMonths: return "3m"
        case .sixMonths: return "6m"
        case .year: return "1y"
        case .forever: return "∞"
        }
    }

    var sliderIndex: Double { Double(rawValue) }

    /// Snaps an arbitrary day count (including ones from before this preset
    /// set existed) to its nearest stop, so old UserDefaults values still
    /// land on a sensible position on the slider.
    init(nearestDays days: Int) {
        self = Self.allCases.min(by: { abs($0.days - days) < abs($1.days - days) }) ?? .month
    }

    init(sliderIndex: Double) {
        let index = min(Self.allCases.count - 1, max(0, Int(sliderIndex.rounded())))
        self = Self.allCases[index]
    }
}

enum ClipColorTheme: Int, CaseIterable, Identifiable {
    case `default`
    case vibrant
    case accentShades
    case appIcon

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .default: "Default"
        case .vibrant: "Vibrant"
        case .accentShades: "Accent shades"
        case .appIcon: "App icon"
        }
    }

    var detail: String {
        switch self {
        case .default:
            "Match each clip to its source app\u{2019}s familiar card color."
        case .vibrant:
            "Give each source app one of Klarglas\u{2019}s bright colors."
        case .accentShades:
            "Give each source app a stable lighter or darker shade of one color."
        case .appIcon:
            "Take each card\u{2019}s color from its source app\u{2019}s icon."
        }
    }
}

/// How long the bar reopens on the tab it was closed on before falling back
/// to Clipboard.
enum TabMemory: Int, CaseIterable, Identifiable {
    case never = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case oneHour = 3600
    case always = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .oneMinute: "For 1 minute"
        case .fiveMinutes: "For 5 minutes"
        case .fifteenMinutes: "For 15 minutes"
        case .oneHour: "For 1 hour"
        case .always: "Always"
        }
    }

    /// Whether a tab left `elapsed` seconds ago is still the one to show.
    func remembers(after elapsed: TimeInterval) -> Bool {
        switch self {
        case .never: false
        case .always: true
        default: elapsed <= TimeInterval(rawValue)
        }
    }
}

enum SelectedClipPosition: Int, CaseIterable, Identifiable {
    case center
    case rightEdge

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .center: "Center"
        case .rightEdge: "Right edge"
        }
    }

    var detail: String {
        switch self {
        case .center: "Keep the selected clip centered with surrounding context visible."
        case .rightEdge: "Place the selected clip at the far right, like Paste."
        }
    }
}

enum BarAppearance: Int, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil lets the bar follow the system appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum BarEdge: Int, CaseIterable, Identifiable {
    case bottom
    case top

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .bottom: "Bottom"
        case .top: "Top"
        }
    }
}

@Observable
@MainActor
final class Settings {
    static let shared = Settings()

    @ObservationIgnored private let d = UserDefaults.standard
    @ObservationIgnored private var isLoaded = false

    enum Keys {
        static let historyLimit = "historyLimit"
        static let historyRetentionMode = "historyRetentionMode"
        static let historyRetentionDays = "historyRetentionDays"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let quickPasteModifier = "quickPasteModifier"
        static let plainTextModifier = "plainTextModifier"
        static let launchAtLogin = "launchAtLogin"
        static let hideOnClickOutside = "hideOnClickOutside"
        static let pasteDirectly = "pasteDirectly"
        static let playSound = "playSound"
        static let playSoundOnCopy = "playSoundOnCopy"
        static let playSoundOnCapture = "playSoundOnCapture"
        static let captureSoundName = "captureSoundName"
        static let shelfForClips = "shelfForClips"
        static let shelfForFolders = "shelfForFolders"
        static let shelfKinds = "shelfKinds"
        static let shelfForOtherDevices = "shelfForOtherDevices"
        static let shelfWatchedFolders = "shelfWatchedFolders"
        static let shelfRemoveAfterDrag = "shelfRemoveAfterDrag"
        static let shelfTextAsFile = "shelfTextAsFile"
        static let promoteOnPaste = "promoteOnPaste"
        static let ignoreConcealed = "ignoreConcealed"
        static let deletePermanently = "deletePermanently"
        static let ignoredSourceAppBundleIDs = "ignoredSourceAppBundleIDs"
        static let barHeight = "barHeight"
        static let showBarResizeHandle = "showBarResizeHandle"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let onboarded = "onboarded"
        static let iCloudSync = "iCloudSync"
        static let cloudKitSync = "cloudKitSync"
        static let clipColorTheme = "clipColorTheme"
        static let clipColorAccentHex = "clipColorAccentHex"
        static let selectedClipPosition = "selectedClipPosition"
        static let barAppearance = "barAppearance"
        static let barEdge = "barEdge"
        static let linkPreviews = "linkPreviews"
        static let showCleanShotHistory = "showCleanShotHistory"
        static let hideWhileScreenSharing = "hideWhileScreenSharing"
        static let pasteStackShortcut = "pasteStackShortcut"
        static let pinnedFolders = "pinnedFolders"
        static let tabOrder = "tabOrder"
        static let expandAbbreviations = "expandAbbreviations"
        static let tabMemory = "tabMemory"
        static let pasteStackKeyCode = "pasteStackKeyCode"
        static let pasteStackModifiers = "pasteStackModifiers"
        static let plainTextPasteShortcut = "plainTextPasteShortcut"
        static let plainTextPasteKeyCode = "plainTextPasteKeyCode"
        static let plainTextPasteModifiers = "plainTextPasteModifiers"
        static let captureTextShortcut = "captureTextShortcut"
        static let captureTextKeyCode = "captureTextKeyCode"
        static let captureTextModifiers = "captureTextModifiers"
    }

    var historyLimit: Int {
        didSet {
            guard isLoaded else { return }
            if historyLimit < 20 { historyLimit = 20; return }
            d.set(historyLimit, forKey: Keys.historyLimit)
        }
    }

    var historyRetentionMode: HistoryRetentionMode {
        didSet {
            guard isLoaded else { return }
            d.set(historyRetentionMode.rawValue, forKey: Keys.historyRetentionMode)
        }
    }

    /// A raw day count for time-based pruning; 0 means forever (no automatic
    /// pruning by age). See `HistoryRetentionPreset` for the named stops the
    /// Settings slider snaps this to.
    var historyRetentionDays: Int {
        didSet {
            guard isLoaded else { return }
            if historyRetentionDays < 0 { historyRetentionDays = 0; return }
            d.set(historyRetentionDays, forKey: Keys.historyRetentionDays)
        }
    }

    var hotkeyKeyCode: Int {
        didSet { guard isLoaded else { return }
            d.set(hotkeyKeyCode, forKey: Keys.hotkeyKeyCode); HotKeyCenter.shared.reload() }
    }

    var hotkeyModifiers: Int {
        didSet { guard isLoaded else { return }
            d.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers); HotKeyCenter.shared.reload() }
    }

    var quickPasteModifier: Int {
        didSet {
            guard isLoaded else { return }
            if quickPasteModifier == plainTextModifier { plainTextModifier = oldValue }
            d.set(quickPasteModifier, forKey: Keys.quickPasteModifier)
        }
    }

    var plainTextModifier: Int {
        didSet {
            guard isLoaded else { return }
            if plainTextModifier == quickPasteModifier { quickPasteModifier = oldValue }
            d.set(plainTextModifier, forKey: Keys.plainTextModifier)
        }
    }

    var launchAtLogin: Bool {
        didSet { guard isLoaded else { return }
            d.set(launchAtLogin, forKey: Keys.launchAtLogin); LaunchAtLogin.set(enabled: launchAtLogin) }
    }

    var hideOnClickOutside: Bool {
        didSet { guard isLoaded else { return }; d.set(hideOnClickOutside, forKey: Keys.hideOnClickOutside) }
    }

    var pasteDirectly: Bool {
        didSet { guard isLoaded else { return }; d.set(pasteDirectly, forKey: Keys.pasteDirectly) }
    }

    var playSound: Bool {
        didSet { guard isLoaded else { return }; d.set(playSound, forKey: Keys.playSound) }
    }

    var playSoundOnCopy: Bool {
        didSet { guard isLoaded else { return }; d.set(playSoundOnCopy, forKey: Keys.playSoundOnCopy) }
    }

    /// A short sound each time a copy lands in Pastely's history.
    var playSoundOnCapture: Bool {
        didSet { guard isLoaded else { return }; d.set(playSoundOnCapture, forKey: Keys.playSoundOnCapture) }
    }

    /// A macOS system sound, see `captureSoundChoices`.
    var captureSoundName: String {
        didSet { guard isLoaded else { return }; d.set(captureSoundName, forKey: Keys.captureSoundName) }
    }

    /// Puts each new copy on the Shelf.
    var shelfForClips: Bool {
        didSet { guard isLoaded else { return }; d.set(shelfForClips, forKey: Keys.shelfForClips) }
    }

    /// Puts each file that lands in a folder tab, such as a download, on the Shelf.
    var shelfForFolders: Bool {
        didSet {
            guard isLoaded else { return }
            d.set(shelfForFolders, forKey: Keys.shelfForFolders)
            FolderLibrary.shared.syncWatchers()
        }
    }

    /// The folders whose new files go on the Shelf, by path; independent of
    /// the folder tabs. Downloads by default.
    var shelfWatchedFolders: [String] {
        didSet {
            guard isLoaded else { return }
            d.set(shelfWatchedFolders, forKey: Keys.shelfWatchedFolders)
            FolderLibrary.shared.syncWatchers()
        }
    }

    /// Which kinds of copies go on the Shelf, as `ClipType` raw values.
    var shelfKinds: Set<String> {
        didSet { guard isLoaded else { return }; d.set(Array(shelfKinds), forKey: Keys.shelfKinds) }
    }

    /// Copies from an iPhone, iPad or other Mac through Continuity's
    /// Universal Clipboard go on the Shelf whatever their kind.
    var shelfForOtherDevices: Bool {
        didSet { guard isLoaded else { return }; d.set(shelfForOtherDevices, forKey: Keys.shelfForOtherDevices) }
    }

    /// Whatever lands somewhere when dragged out leaves the Shelf.
    var shelfRemoveAfterDrag: Bool {
        didSet { guard isLoaded else { return }; d.set(shelfRemoveAfterDrag, forKey: Keys.shelfRemoveAfterDrag) }
    }

    /// Text dragged into Finder becomes a .txt file instead of a text clipping.
    var shelfTextAsFile: Bool {
        didSet { guard isLoaded else { return }; d.set(shelfTextAsFile, forKey: Keys.shelfTextAsFile) }
    }

    /// Whether a copy of this kind goes on the Shelf; rich text counts as text.
    func shelfCollects(_ type: ClipType) -> Bool {
        shelfForClips && shelfKinds.contains((type == .richText ? ClipType.text : type).rawValue)
    }

    /// The bright, short system sounds that read as "done".
    static let captureSoundChoices = ["Glass", "Hero", "Ping", "Pop", "Bottle", "Purr"]

    /// Pasting a clip moves it to the front of history the way copying it
    /// from the bar does. Off by default: history has always been ordered by
    /// when a clip was copied, and the quick-paste numbers would shift on
    /// every paste.
    var promoteOnPaste: Bool {
        didSet { guard isLoaded else { return }; d.set(promoteOnPaste, forKey: Keys.promoteOnPaste) }
    }

    var ignoreConcealed: Bool {
        didSet { guard isLoaded else { return }; d.set(ignoreConcealed, forKey: Keys.ignoreConcealed) }
    }

    /// Deleted clips are purged at once instead of staying restorable with
    /// Command-Z for five minutes.
    var deletePermanently: Bool {
        didSet { guard isLoaded else { return }; d.set(deletePermanently, forKey: Keys.deletePermanently) }
    }

    /// Applications whose copied content should never be recorded in history.
    /// Store bundle identifiers rather than paths so the choice continues to work
    /// when an app is updated or moved.
    private(set) var ignoredSourceAppBundleIDs: [String] {
        didSet { guard isLoaded else { return }; d.set(ignoredSourceAppBundleIDs, forKey: Keys.ignoredSourceAppBundleIDs) }
    }

    var barHeight: Double {
        didSet {
            guard isLoaded else { return }
            let normalized = BarResizeGeometry.normalizedPersistedHeight(barHeight)
            if normalized != barHeight { barHeight = normalized; return }
            d.set(barHeight, forKey: Keys.barHeight)
        }
    }

    var showBarResizeHandle: Bool {
        didSet {
            guard isLoaded else { return }
            d.set(showBarResizeHandle, forKey: Keys.showBarResizeHandle)
        }
    }

    var showMenuBarIcon: Bool {
        didSet {
            guard isLoaded else { return }
            d.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            AppController.shared.setMenuBarIconVisible(showMenuBarIcon)
        }
    }

    var onboarded: Bool {
        didSet { guard isLoaded else { return }; d.set(onboarded, forKey: Keys.onboarded) }
    }

    var iCloudSync: Bool {
        didSet { guard isLoaded else { return }; d.set(iCloudSync, forKey: Keys.iCloudSync) }
    }

    var cloudKitSync: Bool {
        didSet { guard isLoaded else { return }; d.set(cloudKitSync, forKey: Keys.cloudKitSync) }
    }

    var clipColorTheme: ClipColorTheme {
        didSet { guard isLoaded else { return }; d.set(clipColorTheme.rawValue, forKey: Keys.clipColorTheme) }
    }

    var clipColorAccentHex: String {
        didSet { guard isLoaded else { return }; d.set(clipColorAccentHex, forKey: Keys.clipColorAccentHex) }
    }

    var selectedClipPosition: SelectedClipPosition {
        didSet { guard isLoaded else { return }; d.set(selectedClipPosition.rawValue, forKey: Keys.selectedClipPosition) }
    }

    var barAppearance: BarAppearance {
        didSet { guard isLoaded else { return }; d.set(barAppearance.rawValue, forKey: Keys.barAppearance) }
    }

    var barEdge: BarEdge {
        didSet { guard isLoaded else { return }; d.set(barEdge.rawValue, forKey: Keys.barEdge) }
    }

    /// Fetching a preview contacts the link's site, so it can be turned off.
    var linkPreviews: Bool {
        didSet { guard isLoaded else { return }; d.set(linkPreviews, forKey: Keys.linkPreviews) }
    }

    var showCleanShotHistory: Bool {
        didSet { guard isLoaded else { return }; d.set(showCleanShotHistory, forKey: Keys.showCleanShotHistory) }
    }

    /// Keeps the bar out of screen sharing, recordings and screenshots.
    var hideWhileScreenSharing: Bool {
        didSet { guard isLoaded else { return }; d.set(hideWhileScreenSharing, forKey: Keys.hideWhileScreenSharing) }
    }

    var pasteStackShortcut: Bool {
        didSet {
            guard isLoaded else { return }
            d.set(pasteStackShortcut, forKey: Keys.pasteStackShortcut)
            HotKeyCenter.shared.reloadStackHotKey()
        }
    }

    /// Folders listed as pinboards, by path. Downloads by default.
    var pinnedFolders: [String] {
        didSet { guard isLoaded else { return }; d.set(pinnedFolders, forKey: Keys.pinnedFolders) }
    }

    /// The tabs after Clipboard as dragged into place, see `TabOrder`.
    var tabOrder: [String] {
        didSet { guard isLoaded else { return }; d.set(tabOrder, forKey: Keys.tabOrder) }
    }

    var tabMemory: TabMemory {
        didSet { guard isLoaded else { return }; d.set(tabMemory.rawValue, forKey: Keys.tabMemory) }
    }

    var expandAbbreviations: Bool {
        didSet {
            guard isLoaded else { return }
            d.set(expandAbbreviations, forKey: Keys.expandAbbreviations)
            #if !MAS
            TextExpander.shared.refresh()
            #endif
        }
    }

    var pasteStackKeyCode: Int {
        didSet {
            guard isLoaded else { return }
            d.set(pasteStackKeyCode, forKey: Keys.pasteStackKeyCode)
            HotKeyCenter.shared.reloadStackHotKey()
        }
    }

    var pasteStackModifiers: Int {
        didSet {
            guard isLoaded else { return }
            d.set(pasteStackModifiers, forKey: Keys.pasteStackModifiers)
            HotKeyCenter.shared.reloadStackHotKey()
        }
    }

    var pasteStackHotkeyDisplay: String {
        HotKeyCenter.describe(keyCode: pasteStackKeyCode, modifiers: pasteStackModifiers)
    }

    /// Pastes the clipboard without formatting from anywhere.
    var plainTextPasteShortcut: Bool {
        didSet {
            guard isLoaded else { return }
            d.set(plainTextPasteShortcut, forKey: Keys.plainTextPasteShortcut)
            HotKeyCenter.shared.reloadPlainTextHotKey()
        }
    }

    var plainTextPasteKeyCode: Int {
        didSet {
            guard isLoaded else { return }
            d.set(plainTextPasteKeyCode, forKey: Keys.plainTextPasteKeyCode)
            HotKeyCenter.shared.reloadPlainTextHotKey()
        }
    }

    var plainTextPasteModifiers: Int {
        didSet {
            guard isLoaded else { return }
            d.set(plainTextPasteModifiers, forKey: Keys.plainTextPasteModifiers)
            HotKeyCenter.shared.reloadPlainTextHotKey()
        }
    }

    var plainTextPasteHotkeyDisplay: String {
        HotKeyCenter.describe(keyCode: plainTextPasteKeyCode, modifiers: plainTextPasteModifiers)
    }

    /// Copies the text in a part of the screen the user drags over.
    var captureTextShortcut: Bool {
        didSet {
            guard isLoaded else { return }
            d.set(captureTextShortcut, forKey: Keys.captureTextShortcut)
            HotKeyCenter.shared.reloadCaptureTextHotKey()
        }
    }

    var captureTextKeyCode: Int {
        didSet {
            guard isLoaded else { return }
            d.set(captureTextKeyCode, forKey: Keys.captureTextKeyCode)
            HotKeyCenter.shared.reloadCaptureTextHotKey()
        }
    }

    var captureTextModifiers: Int {
        didSet {
            guard isLoaded else { return }
            d.set(captureTextModifiers, forKey: Keys.captureTextModifiers)
            HotKeyCenter.shared.reloadCaptureTextHotKey()
        }
    }

    var captureTextHotkeyDisplay: String {
        HotKeyCenter.describe(keyCode: captureTextKeyCode, modifiers: captureTextModifiers)
    }

    private init() {
        d.register(defaults: [
            Keys.historyLimit: 500,
            Keys.historyRetentionMode: HistoryRetentionMode.itemCount.rawValue,
            Keys.historyRetentionDays: 30,
            Keys.hotkeyKeyCode: kVK_ANSI_V,
            Keys.hotkeyModifiers: cmdKey | shiftKey,
            Keys.quickPasteModifier: cmdKey,
            Keys.plainTextModifier: shiftKey,
            Keys.launchAtLogin: false,
            Keys.hideOnClickOutside: true,
            Keys.pasteDirectly: true,
            Keys.playSound: false,
            // Off by default, matching the paste sound: existing users
            // shouldn't gain a new audible behavior from an update.
            Keys.playSoundOnCopy: false,
            Keys.playSoundOnCapture: true,
            Keys.captureSoundName: "Glass",
            Keys.shelfForClips: true,
            Keys.shelfForFolders: true,
            Keys.shelfWatchedFolders: [Settings.downloadsPath],
            // Text copies are too frequent to stack up by default.
            Keys.shelfKinds: [ClipType.link, .image, .file, .color].map(\.rawValue),
            Keys.shelfForOtherDevices: true,
            Keys.shelfRemoveAfterDrag: true,
            Keys.shelfTextAsFile: true,
            Keys.promoteOnPaste: false,
            Keys.ignoreConcealed: true,
            Keys.deletePermanently: false,
            Keys.ignoredSourceAppBundleIDs: [],
            Keys.barHeight: BarResizeGeometry.defaultHeight,
            Keys.showBarResizeHandle: false,
            Keys.showMenuBarIcon: true,
            Keys.onboarded: false,
            Keys.iCloudSync: false,
            Keys.cloudKitSync: true,
            Keys.clipColorTheme: ClipColorTheme.appIcon.rawValue,
            Keys.clipColorAccentHex: "#FF5A9F",
            Keys.selectedClipPosition: SelectedClipPosition.center.rawValue,
            Keys.barAppearance: BarAppearance.system.rawValue,
            Keys.barEdge: BarEdge.bottom.rawValue,
            Keys.linkPreviews: true,
            Keys.showCleanShotHistory: true,
            Keys.hideWhileScreenSharing: false,
            Keys.pasteStackShortcut: true,
            Keys.pinnedFolders: [Settings.downloadsPath],
            Keys.expandAbbreviations: true,
            Keys.tabMemory: TabMemory.fifteenMinutes.rawValue,
            Keys.pasteStackKeyCode: kVK_ANSI_C,
            Keys.pasteStackModifiers: cmdKey | shiftKey,
            Keys.plainTextPasteShortcut: true,
            Keys.plainTextPasteKeyCode: kVK_ANSI_V,
            Keys.plainTextPasteModifiers: cmdKey | optionKey | shiftKey,
            // Next to the system's ⇧⌘3, ⇧⌘4 and ⇧⌘5, as in TextSniper.
            Keys.captureTextShortcut: true,
            Keys.captureTextKeyCode: kVK_ANSI_2,
            Keys.captureTextModifiers: cmdKey | shiftKey
        ])
        historyLimit = d.integer(forKey: Keys.historyLimit)
        historyRetentionMode = HistoryRetentionMode(rawValue: d.string(forKey: Keys.historyRetentionMode) ?? "")
            ?? .itemCount
        historyRetentionDays = max(0, d.integer(forKey: Keys.historyRetentionDays))
        hotkeyKeyCode = d.integer(forKey: Keys.hotkeyKeyCode)
        hotkeyModifiers = d.integer(forKey: Keys.hotkeyModifiers)
        quickPasteModifier = d.integer(forKey: Keys.quickPasteModifier)
        plainTextModifier = d.integer(forKey: Keys.plainTextModifier)
        launchAtLogin = d.bool(forKey: Keys.launchAtLogin)
        hideOnClickOutside = d.bool(forKey: Keys.hideOnClickOutside)
        pasteDirectly = d.bool(forKey: Keys.pasteDirectly)
        playSound = d.bool(forKey: Keys.playSound)
        playSoundOnCopy = d.bool(forKey: Keys.playSoundOnCopy)
        playSoundOnCapture = d.bool(forKey: Keys.playSoundOnCapture)
        captureSoundName = d.string(forKey: Keys.captureSoundName) ?? "Glass"
        shelfForClips = d.bool(forKey: Keys.shelfForClips)
        shelfForFolders = d.bool(forKey: Keys.shelfForFolders)
        shelfKinds = Set(d.stringArray(forKey: Keys.shelfKinds) ?? [])
        shelfForOtherDevices = d.bool(forKey: Keys.shelfForOtherDevices)
        shelfWatchedFolders = d.stringArray(forKey: Keys.shelfWatchedFolders) ?? []
        shelfRemoveAfterDrag = d.bool(forKey: Keys.shelfRemoveAfterDrag)
        shelfTextAsFile = d.bool(forKey: Keys.shelfTextAsFile)
        promoteOnPaste = d.bool(forKey: Keys.promoteOnPaste)
        ignoreConcealed = d.bool(forKey: Keys.ignoreConcealed)
        deletePermanently = d.bool(forKey: Keys.deletePermanently)
        ignoredSourceAppBundleIDs = (d.stringArray(forKey: Keys.ignoredSourceAppBundleIDs) ?? [])
            .filter { !$0.isEmpty }
        let storedBarHeight = d.double(forKey: Keys.barHeight)
        let normalizedBarHeight = BarResizeGeometry.normalizedPersistedHeight(storedBarHeight)
        barHeight = normalizedBarHeight
        showBarResizeHandle = d.bool(forKey: Keys.showBarResizeHandle)
        showMenuBarIcon = d.bool(forKey: Keys.showMenuBarIcon)
        onboarded = d.bool(forKey: Keys.onboarded)
        iCloudSync = d.bool(forKey: Keys.iCloudSync)
        cloudKitSync = d.bool(forKey: Keys.cloudKitSync)
        clipColorTheme = ClipColorTheme(rawValue: d.integer(forKey: Keys.clipColorTheme)) ?? .default
        clipColorAccentHex = d.string(forKey: Keys.clipColorAccentHex) ?? "#FF5A9F"
        selectedClipPosition = SelectedClipPosition(rawValue: d.integer(forKey: Keys.selectedClipPosition)) ?? .center
        barAppearance = BarAppearance(rawValue: d.integer(forKey: Keys.barAppearance)) ?? .system
        barEdge = BarEdge(rawValue: d.integer(forKey: Keys.barEdge)) ?? .bottom
        linkPreviews = d.bool(forKey: Keys.linkPreviews)
        showCleanShotHistory = d.bool(forKey: Keys.showCleanShotHistory)
        hideWhileScreenSharing = d.bool(forKey: Keys.hideWhileScreenSharing)
        pasteStackShortcut = d.bool(forKey: Keys.pasteStackShortcut)
        pinnedFolders = d.stringArray(forKey: Keys.pinnedFolders) ?? []
        tabOrder = d.stringArray(forKey: Keys.tabOrder) ?? []
        expandAbbreviations = d.bool(forKey: Keys.expandAbbreviations)
        tabMemory = TabMemory(rawValue: d.integer(forKey: Keys.tabMemory)) ?? .fifteenMinutes
        pasteStackKeyCode = d.integer(forKey: Keys.pasteStackKeyCode)
        pasteStackModifiers = d.integer(forKey: Keys.pasteStackModifiers)
        plainTextPasteShortcut = d.bool(forKey: Keys.plainTextPasteShortcut)
        plainTextPasteKeyCode = d.integer(forKey: Keys.plainTextPasteKeyCode)
        plainTextPasteModifiers = d.integer(forKey: Keys.plainTextPasteModifiers)
        captureTextShortcut = d.bool(forKey: Keys.captureTextShortcut)
        captureTextKeyCode = d.integer(forKey: Keys.captureTextKeyCode)
        captureTextModifiers = d.integer(forKey: Keys.captureTextModifiers)
        isLoaded = true
        if normalizedBarHeight != storedBarHeight {
            d.set(normalizedBarHeight, forKey: Keys.barHeight)
        }
    }

    static var downloadsPath: String {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return home + "/Downloads"
    }

    var hotkeyDisplay: String {
        HotKeyCenter.describe(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
    }

    var quickPasteModifierDisplay: String {
        ShortcutModifier(carbonValue: quickPasteModifier)?.symbol ?? "⌘"
    }

    func isIgnoringSourceApp(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return ignoredSourceAppBundleIDs.contains(bundleID)
    }

    func addIgnoredSourceApp(_ bundleID: String) {
        guard !bundleID.isEmpty, !ignoredSourceAppBundleIDs.contains(bundleID) else { return }
        ignoredSourceAppBundleIDs.append(bundleID)
        ignoredSourceAppBundleIDs.sort()
    }

    func removeIgnoredSourceApp(_ bundleID: String) {
        ignoredSourceAppBundleIDs.removeAll { $0 == bundleID }
    }
}
