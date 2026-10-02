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
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(searchMode, forKey: .searchMode)
        try c.encode(pasteByDefault, forKey: .pasteByDefault)
        try c.encode(removeFormattingByDefault, forKey: .removeFormattingByDefault)
        try c.encode(enabledPasteboardTypes, forKey: .enabledPasteboardTypes)
        try c.encode(sortBy, forKey: .sortBy)
        try c.encode(popupPosition, forKey: .popupPosition)
        try c.encode(popupScreen, forKey: .popupScreen)
        try c.encode(windowWidth, forKey: .windowWidth)
        try c.encode(windowHeight, forKey: .windowHeight)
        try c.encode(windowX, forKey: .windowX)
        try c.encode(windowY, forKey: .windowY)
        try c.encode(previewWidth, forKey: .previewWidth)
        try c.encode(pinTo, forKey: .pinTo)
        try c.encode(imageMaxHeight, forKey: .imageMaxHeight)
        try c.encode(openPreviewAutomatically, forKey: .openPreviewAutomatically)
        try c.encode(previewDelay, forKey: .previewDelay)
        try c.encode(highlightMatch, forKey: .highlightMatch)
        try c.encode(showSpecialSymbols, forKey: .showSpecialSymbols)
        try c.encode(showInStatusBar, forKey: .showInStatusBar)
        try c.encode(menuIcon, forKey: .menuIcon)
        try c.encode(showRecentCopyInMenuBar, forKey: .showRecentCopyInMenuBar)
        try c.encode(showSearch, forKey: .showSearch)
        try c.encode(searchVisibility, forKey: .searchVisibility)
        try c.encode(showTitle, forKey: .showTitle)
        try c.encode(showApplicationIcons, forKey: .showApplicationIcons)
        try c.encode(showHexColorSwatch, forKey: .showHexColorSwatch)
        try c.encode(showFooter, forKey: .showFooter)
        try c.encode(ignoredApps, forKey: .ignoredApps)
        try c.encode(ignoreAllAppsExceptListed, forKey: .ignoreAllAppsExceptListed)
        try c.encode(ignoredPasteboardTypes, forKey: .ignoredPasteboardTypes)
        try c.encode(ignoreRegexp, forKey: .ignoreRegexp)
        try c.encode(ignoreEvents, forKey: .ignoreEvents)
        try c.encode(ignoreOnlyNextEvent, forKey: .ignoreOnlyNextEvent)
        try c.encode(clearOnQuit, forKey: .clearOnQuit)
        try c.encode(clearSystemClipboard, forKey: .clearSystemClipboard)
        try c.encode(suppressClearAlert, forKey: .suppressClearAlert)
        try c.encode(clipboardCheckInterval, forKey: .clipboardCheckInterval)
        if let value = popupShortcut { try c.encode(value, forKey: .popupShortcut) } else { try c.encodeNil(forKey: .popupShortcut) }
        if let value = pinShortcut { try c.encode(value, forKey: .pinShortcut) } else { try c.encodeNil(forKey: .pinShortcut) }
        if let value = deleteShortcut { try c.encode(value, forKey: .deleteShortcut) } else { try c.encodeNil(forKey: .deleteShortcut) }
        if let value = previewShortcut { try c.encode(value, forKey: .previewShortcut) } else { try c.encodeNil(forKey: .previewShortcut) }
        try c.encode(openInNotch, forKey: .openInNotch)
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
