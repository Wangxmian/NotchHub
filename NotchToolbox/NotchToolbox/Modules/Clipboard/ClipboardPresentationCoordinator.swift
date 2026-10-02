import AppKit
import Combine
import SwiftUI
import ApplicationServices

@MainActor
final class ClipboardPresentationCoordinator: NSObject, NSWindowDelegate {
    let model: ClipboardViewModel
    private let shortcutService = CarbonGlobalShortcutService(identifier: 2)
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var statusVisibilityObservation: NSKeyValueObservation?
    private var lastPreviewWidth: CGFloat = 0
    private var monitor: Any?
    private var outsideMonitor: Any?
    private var subscriptions: Set<AnyCancellable> = []
    private var registeredShortcut: KeyboardShortcutDescriptor?
    private var cycle = false
    private var opening = false
    private var listWidth: CGFloat = 450
    private var adjustingFrame = false
    var openNotch: (() -> Void)?
    var closeNotch: (() -> Void)?

    init(model: ClipboardViewModel) {
        self.model = model
        super.init()
    }
    func start() {
        applyPreferences()
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification).sink { [weak self] _ in
            DispatchQueue.main.async { self?.resizeForPreview() }
        }.store(in: &subscriptions)
        model.core.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.applyPreferences() }
        }.store(in: &subscriptions)
        model.$previewVisible.dropFirst().sink { [weak self] _ in DispatchQueue.main.async { self?.resizeForPreview() } }.store(in: &subscriptions)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return event }
                if event.type == .keyDown, self.model.matches(event, shortcut: self.model.preferences.popupShortcut) { self.hotKey(); return nil }
                if event.type == .flagsChanged, self.model.isPresented {
                    let released = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
                    if released && self.cycle { self.cycle = false; self.model.activateSelection() }
                    if released { self.opening = false }
                    return event
                }
                return event.type == .keyDown ? self.model.handleKey(event) : event
            }
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closeFloating() }
        }
    }
    private func applyPreferences() {
        let p = model.preferences
        if registeredShortcut != p.popupShortcut {
            shortcutService.unregister(); registeredShortcut = nil
            if let shortcut = p.popupShortcut {
                do { try shortcutService.register(shortcut) { [weak self] in self?.hotKey() }; registeredShortcut = shortcut }
                catch { model.core.onError?("剪贴板快捷键冲突：\(error)") }
            }
        }
        if p.showInStatusBar {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                item.button?.target = self; item.button?.action = #selector(statusClicked)
                item.behavior = .removalAllowed; statusItem = item
                statusVisibilityObservation = item.observe(\.isVisible, options: [.new]) { [weak self] item, _ in
                    Task { @MainActor in
                        guard let self, self.statusItem === item, !item.isVisible else { return }
                        self.model.updatePreferences { $0.showInStatusBar = false }
                    }
                }
            }
            let symbol: String
            switch p.menuIcon { case "clipboard": symbol = "doc.on.clipboard"; case "scissors": symbol = "scissors"; case "paperclip": symbol = "paperclip"; default: symbol = "rectangle.topthird.inset.filled" }
            statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "NotchHub 剪贴板")
            statusItem?.button?.appearsDisabled = p.ignoreEvents || p.enabledPasteboardTypes.isEmpty
            let recent = model.core.sortedHistory.first { !$0.isPinned }.flatMap { try? model.core.fullText($0) } ?? ""
            var menuText = String(recent.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
            menuText.unicodeScalars.removeAll { CharacterSet.newlines.contains($0) }
            statusItem?.button?.title = p.showRecentCopyInMenuBar ? String(menuText.prefix(20)) : ""
            statusItem?.button?.setAccessibilityLabel("NotchHub 剪贴板")
        } else if let statusItem { NSStatusBar.system.removeStatusItem(statusItem); self.statusItem = nil; statusVisibilityObservation = nil }
        if panel?.isVisible == true { resizeForPreview() }
    }
    private func hotKey() {
        if model.isPresented {
            if opening || cycle { opening = false; cycle = true; model.moveSelection(1, wrap: true) }
            else { closeFloating(); closeNotch?(); model.isPresented = false }
            return
        }
        model.captureTarget()
        opening = true; cycle = false
        if model.preferences.openInNotch { closeFloating(); openNotch?() }
        else { openFloating() }
    }
    @objc private func statusClicked() {
        let flags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        if flags.contains(.option) {
            model.updatePreferences { p in
                p.ignoreEvents.toggle()
                if flags.contains(.shift) { p.ignoreOnlyNextEvent = p.ignoreEvents }
            }
            return
        }
        if panel?.isVisible == true { closeFloating() } else { openFloating(position: "statusItem") }
    }
    func openFloating(position: String? = nil) {
        closeNotch?()
        model.activePresentationID = nil; model.presentationIsFloating = true
        model.captureTarget(); model.query = ""; model.filter = "all"; model.refresh()
        let p = model.preferences
        let active = screenForPopup()
        listWidth = min(max(250, p.windowWidth), active.visibleFrame.width)
        let height = min(max(180, p.windowHeight), active.visibleFrame.height)
        if panel == nil {
            let panel = ClipboardFloatingPanel(contentRect: NSRect(x: 0, y: 0, width: listWidth, height: height), styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.level = .popUpMenu; panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true; panel.delegate = self
            panel.contentView = NSHostingView(rootView: ClipboardBrowserView(model: model, close: { [weak self] in self?.closeFloating() }, floating: true))
            self.panel = panel
        }
        lastPreviewWidth = 0; model.previewOnLeft = false
        panel?.setContentSize(NSSize(width: listWidth, height: height))
        let origin = popupOrigin(position ?? p.popupPosition, size: panel!.frame.size, screen: active)
        panel?.setFrameOrigin(origin); panel?.orderFrontRegardless(); panel?.makeKey()
        model.isPresented = true; model.closePresentation = { [weak self] in self?.closeFloating() }
        model.previewVisible = false; model.schedulePreview(); model.focusRequest += 1
    }
    func closeFloating() {
        guard panel?.isVisible == true else { return }
        panel?.orderOut(nil); model.isPresented = false; model.isInputFocused = false
        opening = false; cycle = false
    }
    func showSettings() { closeFloating(); model.showSettings() }
    func windowWillClose(_ notification: Notification) { model.isPresented = false }
    func windowDidResize(_ notification: Notification) { saveGeometry() }
    func windowDidMove(_ notification: Notification) { saveGeometry() }
    private func saveGeometry() {
        guard !adjustingFrame, let panel, panel.isVisible, let screen = panel.screen else { return }
        let area = screen.visibleFrame
        let preview = lastPreviewWidth
        let width = max(250, panel.frame.width - preview)
        listWidth = width
        model.updatePreferences {
            $0.windowWidth = width; $0.windowHeight = panel.frame.height
            $0.windowX = (panel.frame.minX + (model.previewOnLeft ? preview : 0) + width/2 - area.minX)/area.width
            $0.windowY = (panel.frame.maxY - area.minY)/area.height
        }
    }
    private func resizeForPreview() {
        guard let panel, panel.isVisible else { return }
        let screen = panel.screen ?? screenForPopup()
        var list = panel.frame
        if model.previewOnLeft { list.origin.x += lastPreviewWidth }
        list.size.width = model.preferences.windowWidth
        list.size.height = model.preferences.windowHeight
        let layout = ClipboardPopupLayout.fit(list: list, screen: screen.visibleFrame,
            previewWidth: model.previewVisible && model.selectedItem != nil ? model.preferences.previewWidth : nil)
        lastPreviewWidth = layout.previewWidth
        if model.previewOnLeft != layout.previewOnLeft { model.previewOnLeft = layout.previewOnLeft }
        if model.presentedPreviewWidth != layout.previewWidth { model.presentedPreviewWidth = layout.previewWidth }
        adjustingFrame = true; panel.setFrame(layout.frame, display: true); adjustingFrame = false
    }
    private func screenForPopup() -> NSScreen {
        let screens = NSScreen.screens
        let p = model.preferences
        if p.popupScreen > 0 && p.popupScreen <= screens.count && ["center","lastPosition"].contains(p.popupPosition) { return screens[p.popupScreen-1] }
        return screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? screens[0]
    }
    private func popupOrigin(_ position: String, size: NSSize, screen: NSScreen) -> NSPoint {
        let p = model.preferences; let frame = screen.visibleFrame
        var point = NSPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y-size.height)
        switch position {
        case "center": point = NSPoint(x: frame.midX-size.width/2, y: frame.midY-size.height/2)
        case "lastPosition": point = NSPoint(x: frame.minX+frame.width*p.windowX-size.width/2, y: frame.minY+frame.height*p.windowY-size.height)
        case "statusItem":
            if let button = statusItem?.button, let window = button.window {
                let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
                point = NSPoint(x: rect.minX, y: rect.minY-size.height)
            }
        case "window":
            if AXIsProcessTrusted(), let app = model.targetApplication {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value) == .success, let value {
                    let window = value as! AXUIElement; var pos: CFTypeRef?; var extent: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &pos) == .success,
                       AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &extent) == .success, let pos, let extent {
                        var origin = CGPoint.zero; var dimensions = CGSize.zero
                        AXValueGetValue(pos as! AXValue, .cgPoint, &origin); AXValueGetValue(extent as! AXValue, .cgSize, &dimensions)
                        let top = NSScreen.screens.first?.frame.maxY ?? frame.maxY
                        point = NSPoint(x: origin.x+dimensions.width/2-size.width/2, y: top-origin.y-dimensions.height/2-size.height/2)
                    }
                }
            }
        default: break
        }
        return NSPoint(x: min(max(point.x, frame.minX), frame.maxX-size.width), y: min(max(point.y, frame.minY), frame.maxY-size.height))
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }; if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
    }
}
private final class ClipboardFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
