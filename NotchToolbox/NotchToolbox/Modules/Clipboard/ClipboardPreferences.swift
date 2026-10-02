import Foundation

nonisolated struct ClipboardPreferences: Codable, Equatable {
    var searchMode: String = "exact"
    var pasteByDefault: Bool = false
    var removeFormattingByDefault: Bool = false
    var enabledPasteboardTypes: [String] = ["public.file-url", "public.png", "public.tiff", "public.jpeg", "public.heic", "public.html", "public.rtf", "public.utf8-plain-text"]
    var sortBy: String = "lastCopiedAt"
    var popupPosition: String = "cursor"
    var popupScreen: Int = 0
    var windowWidth: Double = 450
    var windowHeight: Double = 800
    var windowX: Double = 0.5
    var windowY: Double = 0.8
    var previewWidth: Double = 400
    var pinTo: String = "top"
    var imageMaxHeight: Int = 40
    var openPreviewAutomatically: Bool = true
    var previewDelay: Int = 1500
    var highlightMatch: String = "bold"
    var showSpecialSymbols: Bool = true
    var showInStatusBar: Bool = true
    var menuIcon: String = "brand"
    var showRecentCopyInMenuBar: Bool = false
    var showSearch: Bool = true
    var searchVisibility: String = "always"
    var showTitle: Bool = true
    var showApplicationIcons: Bool = false
    var showHexColorSwatch: Bool = true
    var showFooter: Bool = true
    var ignoredApps: [String] = []
    var ignoreAllAppsExceptListed: Bool = false
    var ignoredPasteboardTypes: [String] = ["Pasteboard generator type", "com.agilebits.onepassword", "com.typeit4me.clipping", "de.petermaurer.TransientPasteboardType", "net.antelle.keeweb"]
    var ignoreRegexp: [String] = []
    var ignoreEvents: Bool = false
    var ignoreOnlyNextEvent: Bool = false
    var clearOnQuit: Bool = false
    var clearSystemClipboard: Bool = false
    var suppressClearAlert: Bool = false
    var clipboardCheckInterval: Double = 0.5
    var popupShortcut: KeyboardShortcutDescriptor? = .init(keyEquivalent: "c", modifiers: [.command, .shift])
    var pinShortcut: KeyboardShortcutDescriptor? = .init(keyEquivalent: "p", modifiers: [.option])
    var deleteShortcut: KeyboardShortcutDescriptor? = .init(keyEquivalent: "\u{7f}", modifiers: [.option])
    var previewShortcut: KeyboardShortcutDescriptor? = .init(keyEquivalent: " ", modifiers: [.control])
    var openInNotch: Bool = false
    init() {}
    private enum CodingKeys: String, CodingKey {
        case searchMode, pasteByDefault, removeFormattingByDefault, enabledPasteboardTypes, sortBy, popupPosition, popupScreen, windowWidth, windowHeight, windowX, windowY, previewWidth, pinTo, imageMaxHeight, openPreviewAutomatically, previewDelay, highlightMatch, showSpecialSymbols, showInStatusBar, menuIcon, showRecentCopyInMenuBar, showSearch, searchVisibility, showTitle, showApplicationIcons, showHexColorSwatch, showFooter, ignoredApps, ignoreAllAppsExceptListed, ignoredPasteboardTypes, ignoreRegexp, ignoreEvents, ignoreOnlyNextEvent, clearOnQuit, clearSystemClipboard, suppressClearAlert, clipboardCheckInterval, popupShortcut, pinShortcut, deleteShortcut, previewShortcut, openInNotch
    }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        searchMode = try c.decodeIfPresent(String.self, forKey: .searchMode) ?? searchMode
        pasteByDefault = try c.decodeIfPresent(Bool.self, forKey: .pasteByDefault) ?? pasteByDefault
        removeFormattingByDefault = try c.decodeIfPresent(Bool.self, forKey: .removeFormattingByDefault) ?? removeFormattingByDefault
        enabledPasteboardTypes = try c.decodeIfPresent([String].self, forKey: .enabledPasteboardTypes) ?? enabledPasteboardTypes
        sortBy = try c.decodeIfPresent(String.self, forKey: .sortBy) ?? sortBy
        popupPosition = try c.decodeIfPresent(String.self, forKey: .popupPosition) ?? popupPosition
        popupScreen = try c.decodeIfPresent(Int.self, forKey: .popupScreen) ?? popupScreen
        windowWidth = try c.decodeIfPresent(Double.self, forKey: .windowWidth) ?? windowWidth
        windowHeight = try c.decodeIfPresent(Double.self, forKey: .windowHeight) ?? windowHeight
        windowX = try c.decodeIfPresent(Double.self, forKey: .windowX) ?? windowX
        windowY = try c.decodeIfPresent(Double.self, forKey: .windowY) ?? windowY
        previewWidth = try c.decodeIfPresent(Double.self, forKey: .previewWidth) ?? previewWidth
        pinTo = try c.decodeIfPresent(String.self, forKey: .pinTo) ?? pinTo
        imageMaxHeight = try c.decodeIfPresent(Int.self, forKey: .imageMaxHeight) ?? imageMaxHeight
        openPreviewAutomatically = try c.decodeIfPresent(Bool.self, forKey: .openPreviewAutomatically) ?? openPreviewAutomatically
        previewDelay = try c.decodeIfPresent(Int.self, forKey: .previewDelay) ?? previewDelay
        highlightMatch = try c.decodeIfPresent(String.self, forKey: .highlightMatch) ?? highlightMatch
        showSpecialSymbols = try c.decodeIfPresent(Bool.self, forKey: .showSpecialSymbols) ?? showSpecialSymbols
        showInStatusBar = try c.decodeIfPresent(Bool.self, forKey: .showInStatusBar) ?? showInStatusBar
        menuIcon = try c.decodeIfPresent(String.self, forKey: .menuIcon) ?? menuIcon
        showRecentCopyInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showRecentCopyInMenuBar) ?? showRecentCopyInMenuBar
        showSearch = try c.decodeIfPresent(Bool.self, forKey: .showSearch) ?? showSearch
        searchVisibility = try c.decodeIfPresent(String.self, forKey: .searchVisibility) ?? searchVisibility
        showTitle = try c.decodeIfPresent(Bool.self, forKey: .showTitle) ?? showTitle
        showApplicationIcons = try c.decodeIfPresent(Bool.self, forKey: .showApplicationIcons) ?? showApplicationIcons
        showHexColorSwatch = try c.decodeIfPresent(Bool.self, forKey: .showHexColorSwatch) ?? showHexColorSwatch
        showFooter = try c.decodeIfPresent(Bool.self, forKey: .showFooter) ?? showFooter
        ignoredApps = try c.decodeIfPresent([String].self, forKey: .ignoredApps) ?? ignoredApps
        ignoreAllAppsExceptListed = try c.decodeIfPresent(Bool.self, forKey: .ignoreAllAppsExceptListed) ?? ignoreAllAppsExceptListed
        ignoredPasteboardTypes = try c.decodeIfPresent([String].self, forKey: .ignoredPasteboardTypes) ?? ignoredPasteboardTypes
        ignoreRegexp = try c.decodeIfPresent([String].self, forKey: .ignoreRegexp) ?? ignoreRegexp
        ignoreEvents = try c.decodeIfPresent(Bool.self, forKey: .ignoreEvents) ?? ignoreEvents
        ignoreOnlyNextEvent = try c.decodeIfPresent(Bool.self, forKey: .ignoreOnlyNextEvent) ?? ignoreOnlyNextEvent
        clearOnQuit = try c.decodeIfPresent(Bool.self, forKey: .clearOnQuit) ?? clearOnQuit
        clearSystemClipboard = try c.decodeIfPresent(Bool.self, forKey: .clearSystemClipboard) ?? clearSystemClipboard
        suppressClearAlert = try c.decodeIfPresent(Bool.self, forKey: .suppressClearAlert) ?? suppressClearAlert
        clipboardCheckInterval = try c.decodeIfPresent(Double.self, forKey: .clipboardCheckInterval) ?? clipboardCheckInterval
        if c.contains(.popupShortcut) { popupShortcut = try c.decodeIfPresent(KeyboardShortcutDescriptor.self, forKey: .popupShortcut) }
        if c.contains(.pinShortcut) { pinShortcut = try c.decodeIfPresent(KeyboardShortcutDescriptor.self, forKey: .pinShortcut) }
        if c.contains(.deleteShortcut) { deleteShortcut = try c.decodeIfPresent(KeyboardShortcutDescriptor.self, forKey: .deleteShortcut) }
        if c.contains(.previewShortcut) { previewShortcut = try c.decodeIfPresent(KeyboardShortcutDescriptor.self, forKey: .previewShortcut) }
        openInNotch = try c.decodeIfPresent(Bool.self, forKey: .openInNotch) ?? openInNotch
    }
}
