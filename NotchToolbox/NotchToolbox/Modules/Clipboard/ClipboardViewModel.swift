import AppKit
import ApplicationServices
import Combine
import Foundation

enum ClipboardExpandedPhase: Equatable {
    case history
    case pastebackSuccess
}

@MainActor
final class ClipboardViewModel: ObservableObject {
    typealias DelayScheduler = @MainActor (Duration, @escaping @MainActor () -> Void) -> Task<Void, Never>

    @Published private(set) var cards: [ClipboardCardViewState] = []
    @Published private(set) var isEmpty = true
    @Published private(set) var lastPasteError: String?
    /// Bumped every time a paste error is reported, even when the message is
    /// identical to the previous one, so the view can fire a toast reliably on
    /// repeated failures.
    @Published private(set) var pasteErrorToken: Int = 0
    @Published private(set) var phase: ClipboardExpandedPhase = .history

    private static let missingItemErrorMessage = "该候选内容已不可用，请重新复制后再试。"
    private static let genericPasteErrorMessage = "放回剪贴板失败，请重试。"

    let core: ClipboardCore
    @Published var query = "" { didSet { scheduleSearch() } }
    @Published var selectedID: UUID? { didSet { if selectedID != nil { selectedFooter = nil } } }
    @Published var selectedFooter: Int?
    @Published private(set) var results: [ClipboardSearchService.Result] = []
    @Published var isInputFocused = false
    @Published var focusRequest = 0
    var presentationIsFloating = false
    @Published var previewVisible = false
    @Published var previewOnLeft = false
    @Published var presentedPreviewWidth: CGFloat = 400
    @Published var filter = "all" { didSet { scheduleSearch() } }
    var targetApplication: NSRunningApplication?
    var closePresentation: (() -> Void)?
    var isPresented = false
    var activePresentationID: UUID?
    private var searchTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    var preferences: ClipboardPreferences { core.preferences }
    var selectedItem: ClipboardHistoryItem? { results.first { $0.id == selectedID }?.item }

    func perform(_ id: UUID, action: ClipboardAction? = nil, close: (() -> Void)? = nil) {
        guard let item = core.history.first(where: { $0.id == id }),
              let action = action ?? ClipboardActionResolver.resolve(NSEvent.modifierFlags, preferences: preferences) else { return }
        do {
            try core.paste(item: item, removeFormatting: action == .pastePlainText || action == .copyPlainText)
            lastPasteError = nil
            (close ?? closePresentation)?()
            query = ""
            if action == .paste || action == .pastePlainText { sendPasteToTarget() }
        } catch { reportPasteError(error.localizedDescription) }
    }
    func captureTarget() {
        if let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier { targetApplication = app }
    }
    private func sendPasteToTarget() {
        if let directPasteHandler { directPasteHandler(); return }
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            reportPasteError("已复制。请在系统设置中授权 NotchHub 辅助功能后使用直接粘贴。")
            return
        }
        guard let target = targetApplication, !target.isTerminated else { reportPasteError("已复制，原应用已不可用，请手动粘贴。"); return }
        target.activate(options: .activateIgnoringOtherApps)
        Task { @MainActor [weak self] in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(25))
                if NSEvent.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty { break }
            }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
                  NSEvent.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else {
                self?.reportPasteError("已复制，无法恢复原应用焦点，请手动粘贴。"); return
            }
            let source = CGEventSource(stateID: .combinedSessionState)
            source?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents], state: .eventSuppressionStateSuppressionInterval)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyboardShortcutCarbonMapper.commandSwitchesToQWERTY ? 9 : KeyboardShortcutCarbonMapper.currentLayoutKeyCode("v") ?? 9), keyDown: down)
                event?.flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x8)
                event?.post(tap: .cgSessionEventTap)
            }
        }
    }
    func pin(_ id: UUID) { do { try core.togglePin(id); query = ""; refresh(); selectedID = id; schedulePreview() } catch { reportPasteError(error.localizedDescription) } }
    func delete(_ id: UUID) { do { try core.delete(id) } catch { reportPasteError(error.localizedDescription) } }
    func clear(includingPinned: Bool = false) {
        if !preferences.suppressClearAlert {
            let alert = NSAlert(); alert.messageText = includingPinned ? "清空所有剪贴板历史？" : "清空普通剪贴板历史？"
            alert.informativeText = includingPinned ? "固定内容也将删除。" : "固定内容会保留。"
            alert.addButton(withTitle: "清空"); alert.addButton(withTitle: "取消")
            alert.showsSuppressionButton = true
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            if alert.suppressionButton?.state == .on { updatePreferences { $0.suppressClearAlert = true } }
        }
        do { try core.clear(includingPinned: includingPinned) } catch { reportPasteError(error.localizedDescription) }
    }
    func updatePreferences(_ mutate: (inout ClipboardPreferences) -> Void) {
        do { try core.updatePreferences(mutate); refresh(); objectWillChange.send() } catch { reportPasteError(error.localizedDescription) }
    }
    func showSettings() { NotificationCenter.default.post(name: .notchHubClipboardSettings, object: nil) }
    func moveSelection(_ delta: Int, wrap: Bool = false) {
        if let footer = selectedFooter, preferences.showFooter {
            if delta < 0 && footer == 0 { selectedID = results.last?.id }
            else { selectedFooter = delta > 0 ? (footer + 1) % 4 : footer - 1 }
            return
        }
        guard !results.isEmpty else { if preferences.showFooter { selectedFooter = 0 }; return }
        let index = results.firstIndex { $0.id == selectedID } ?? (delta > 0 ? -1 : results.count)
        if index + delta >= results.count, preferences.showFooter { selectedID = nil; selectedFooter = 0; previewVisible = false; previewTask?.cancel(); return }
        let next = wrap ? (index + delta + results.count) % results.count : min(max(0, index + delta), results.count - 1)
        selectedID = results[next].id
        schedulePreview()
    }
    func selectLast() {
        if preferences.showFooter, selectedFooter != nil { selectedID = nil; selectedFooter = 3 }
        else if preferences.showFooter, selectedID == results.last?.id { selectedID = nil; selectedFooter = 0 }
        else { selectedID = results.last?.id }
    }
    func activateSelection(flags: NSEvent.ModifierFlags = NSEvent.modifierFlags) {
        if let footer = selectedFooter { activateFooter(footer, flags: flags); return }
        if let id = selectedID { if let action = ClipboardActionResolver.resolve(flags, preferences: preferences) { perform(id, action: action) } }
        else { do { try core.copyQuery(query); query = "" } catch { reportPasteError(error.localizedDescription) } }
    }
    func activateFooter(_ index: Int, flags: NSEvent.ModifierFlags = NSEvent.modifierFlags) {
        switch index {
        case 0: clear(includingPinned: flags.contains(.shift))
        case 1: showSettings()
        case 2: showSettings(); NotificationCenter.default.post(name: .init("NotchHub.about"), object: nil)
        default: NSApp.terminate(nil)
        }
    }
    func schedulePreview() {
        previewTask?.cancel()
        guard selectedItem != nil else { previewVisible = false; return }
        guard preferences.openPreviewAutomatically else { return }
        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(self.preferences.previewDelay))
            if !Task.isCancelled { self.previewVisible = true }
        }
    }
    func rebuildSearch() {
        var items = core.sortedHistory
        switch filter {
        case "text": items = items.filter { [.plainText, .richText, .figmaText].contains($0.contentType) }
        case "image": items = items.filter { [.image, .svg, .figmaGraphic].contains($0.contentType) }
        case "file": items = items.filter { $0.contentType == .file }
        case "pinned": items = items.filter(\.isPinned)
        default: break
        }
        results = ClipboardSearchService().search(query, items: items, mode: preferences.searchMode, preferences: preferences)
        if selectedFooter == nil, !results.contains(where: { $0.id == selectedID }) { selectedID = results.first { !$0.item.isPinned }?.id ?? results.first?.id }
    }
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200)); guard !Task.isCancelled else { return }
            self?.rebuildSearch()
            if self?.query.isEmpty == false { self?.selectedID = self?.results.first?.id }
            self?.schedulePreview()
        }
    }
    func handleKey(_ event: NSEvent) -> NSEvent? {
        guard isPresented else { return event }
        if let input = NSApp?.keyWindow?.firstResponder as? NSTextView, input.hasMarkedText() { return event }
        let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        let key = KeyboardShortcutCarbonMapper.keyEquivalent(for: event.keyCode, command: f.contains(.command)) ?? event.charactersIgnoringModifiers?.lowercased() ?? ""
        if event.keyCode == 53 { closePresentation?(); return nil }
        if f == .command && key == "," { showSettings(); return nil }
        if f == .command && key == "q" { NSApp.terminate(nil); return nil }
        if event.keyCode == 51 && (f == [.command, .option] || f == [.command, .option, .shift]) { clear(includingPinned: f.contains(.shift)); return nil }
        if matches(event, shortcut: preferences.pinShortcut) { if let id = selectedID { pin(id) }; return nil }
        if matches(event, shortcut: preferences.deleteShortcut) { if let id = selectedID { delete(id) }; return nil }
        if matches(event, shortcut: preferences.previewShortcut) { previewVisible.toggle(); return nil }
        if [36, 76].contains(event.keyCode) {
            activateSelection(flags: f)
            return nil
        }
        let controlNavigation: [NSEvent.ModifierFlags] = [.control, [.control, .shift], [.control, .option], [.control, .option, .shift]]
        let arrowModifiers = f.isEmpty || f == .shift || f.contains(.command) || f.contains(.option)
        if event.keyCode == 125 && arrowModifiers || key == "n" && controlNavigation.contains(f) || key == "j" && f == .control {
            if f.contains(.command) || f.contains(.option) { selectLast() } else { moveSelection(1) }; return nil
        }
        if event.keyCode == 126 && arrowModifiers || key == "p" && controlNavigation.contains(f) || key == "k" && f == .control {
            if key == "k" && selectedID == results.first?.id { return event }
            if f.contains(.command) || f.contains(.option) { selectedID = results.first?.id } else { moveSelection(-1) }; return nil
        }
        if event.keyCode == 116 && f.isEmpty { selectedID = results.first?.id; return nil }
        if event.keyCode == 121 && f.isEmpty { selectLast(); return nil }
        if f == .control {
            if key == "u" { focusRequest += 1; query = ""; return nil }
            if key == "h" { focusRequest += 1; if !query.isEmpty { query.removeLast() }; return nil }
            if key == "w" { focusRequest += 1; let rest = query.split(separator: " ").dropLast().joined(separator: " "); query = rest.isEmpty ? "" : rest + " "; return nil }
        }
        if !f.isEmpty, let action = ClipboardActionResolver.resolve(f, preferences: preferences) {
            let ordinary = results.filter { !$0.item.isPinned }
            if let number = Int(key), (1...9).contains(number), number <= ordinary.count { perform(ordinary[number-1].id, action: action); return nil }
            if let item = results.first(where: { $0.item.pinKey == key && !key.isEmpty }) { perform(item.id, action: action); return nil }
        }
        return event
    }
    func matches(_ event: NSEvent, shortcut: KeyboardShortcutDescriptor?) -> Bool {
        guard let shortcut else { return false }
        let flags = shortcut.modifiers.reduce(NSEvent.ModifierFlags()) { partial, item in partial.union(item.eventFlags) }
        return event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function]) == flags && UInt32(event.keyCode) == (try? KeyboardShortcutCarbonMapper.keyCode(for: shortcut.keyEquivalent, command: flags.contains(.command)))
    }

    private let directPasteHandler: (() -> Void)?
    private let thumbnailsDirectoryURL: URL?
    private let referenceValidator: ClipboardReferenceValidator
    private let successPhaseDuration: Duration
    private let postCollapseResetDelay: Duration
    private let delayScheduler: DelayScheduler
    private var cancellables: Set<AnyCancellable> = []
    private var pendingSuccessCollapseTask: Task<Void, Never>?
    private var pendingSuccessResetTask: Task<Void, Never>?

    init(
        core: ClipboardCore,
        localFileStore: LocalFileStore? = nil,
        referenceValidator: ClipboardReferenceValidator? = nil,
        successPhaseDuration: Duration = .seconds(2),
        postCollapseResetDelay: Duration = .milliseconds(250),
        delayScheduler: DelayScheduler? = nil,
        directPasteHandler: (() -> Void)? = nil
    ) {
        self.core = core
        self.directPasteHandler = directPasteHandler
        self.thumbnailsDirectoryURL = localFileStore?.url(for: .clipboardThumbnails)
        self.referenceValidator = referenceValidator ?? ClipboardReferenceValidator()
        self.successPhaseDuration = successPhaseDuration
        self.postCollapseResetDelay = postCollapseResetDelay
        self.delayScheduler = delayScheduler ?? Self.defaultDelayScheduler
        core.onError = { [weak self] message in self?.reportPasteError(message) }
        core.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }.store(in: &cancellables)
        core.$history
            .sink { [weak self] history in
                self?.apply(history: history)
            }
            .store(in: &cancellables)
    }

    func refresh() {
        apply(history: core.history)
    }

    func paste(itemID: UUID, onSuccess: (() -> Void)? = nil) {
        guard let item = core.history.first(where: { $0.id == itemID }) else {
            reportPasteError(Self.missingItemErrorMessage)
            return
        }

        do {
            try core.paste(item: item)
            lastPasteError = nil
            beginPastebackSuccessPhase(onCollapseRequested: onSuccess)
        } catch {
            reportPasteError(Self.makePasteErrorMessage(from: error))
        }
    }

    private func reportPasteError(_ message: String) {
        lastPasteError = message
        pasteErrorToken += 1
    }

    private func apply(history: [ClipboardHistoryItem]) {
        cards = history.map(makeCard)
        isEmpty = history.isEmpty
        rebuildSearch()
    }

    private func makeCard(_ item: ClipboardHistoryItem) -> ClipboardCardViewState {
        let isMissingReference = hasMissingReference(item)
        let thumbnail = makeThumbnail(from: item.thumbnail)
        let previewState: ClipboardCardPreviewState

        if isMissingReference {
            if let thumbnail {
                previewState = .thumbnailWithMissingReference(thumbnail)
            } else {
                previewState = .missingReferencePlaceholder
            }
        } else if let thumbnail {
            previewState = .thumbnail(thumbnail)
        } else {
            previewState = .textOnly
        }

        return ClipboardCardViewState(
            id: item.id,
            sourceTitle: item.sourceAppName ?? "Unknown",
            sourceAppBundleID: item.sourceAppBundleID,
            sourceAppName: item.sourceAppName,
            relativeTimeText: Self.relativeTimeText(for: item.copiedAt, relativeTo: Date()),
            previewText: item.previewText,
            previewState: previewState,
            contentType: item.contentType,
            isPastebackSupported: true
        )
    }

    private func hasMissingReference(_ item: ClipboardHistoryItem) -> Bool {
        guard case let .fileReferences(references) = item.payload else {
            return false
        }

        do {
            _ = try referenceValidator.validate(references)
            return false
        } catch {
            return true
        }
    }

    private func makeThumbnail(
        from descriptor: ClipboardThumbnailDescriptor?
    ) -> ClipboardCardThumbnail? {
        guard
            let descriptor,
            let thumbnailsDirectoryURL
        else {
            return nil
        }

        let url = thumbnailsDirectoryURL.appending(path: descriptor.fileName)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }

        return ClipboardCardThumbnail(
            url: url,
            kind: descriptor.kind,
            pixelWidth: descriptor.pixelWidth,
            pixelHeight: descriptor.pixelHeight
        )
    }

    private static func makePasteErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError {
            return "原文件已不存在，无法重新放回剪贴板。"
        }
        return genericPasteErrorMessage
    }

    // Deliberately coarse buckets: cards show a vague age, not a precise
    // timestamp (e.g. anything from 11 to 30 minutes reads as "15 分钟前").
    static func relativeTimeText(for date: Date, relativeTo now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minute = 60.0
        let hour = 60.0 * minute
        let day = 24.0 * hour
        let week = 7.0 * day
        let month = 30.0 * day

        let buckets: [(upperBound: Double, text: (Double) -> String)] = [
            (minute, { _ in "现在" }),
            (11 * minute, { "\(Int($0 / minute)) 分钟前" }),
            (30 * minute, { _ in "15 分钟前" }),
            (hour, { _ in "半小时前" }),
            (12 * hour, { "\(Int($0 / hour)) 小时前" }),
            (day, { _ in "半天前" }),
            (week, { "\(Int($0 / day)) 天前" }),
            (2 * week, { _ in "一周前" }),
            (3 * week, { _ in "两周前" }),
            (4 * week, { _ in "三周前" }),
            (2 * month, { _ in "一个月前" }),
            (3 * month, { _ in "两个月前" }),
            (4 * month, { _ in "三个月前" }),
            (5 * month, { _ in "四个月前" }),
            (6 * month, { _ in "五个月前" }),
            (12 * month, { _ in "半年前" }),
            (24 * month, { _ in "一年前" }),
        ]

        for bucket in buckets where seconds < bucket.upperBound {
            return bucket.text(seconds)
        }

        return "更久"
    }

    private func beginPastebackSuccessPhase(onCollapseRequested: (() -> Void)?) {
        pendingSuccessCollapseTask?.cancel()
        pendingSuccessResetTask?.cancel()
        phase = .pastebackSuccess

        pendingSuccessCollapseTask = delayScheduler(successPhaseDuration) { [weak self] in
            onCollapseRequested?()
            self?.scheduleHistoryPhaseReset()
        }
    }

    private func scheduleHistoryPhaseReset() {
        pendingSuccessResetTask?.cancel()
        pendingSuccessResetTask = delayScheduler(postCollapseResetDelay) { [weak self] in
            self?.phase = .history
        }
    }

    private static func defaultDelayScheduler(
        after delay: Duration,
        action: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard Task.isCancelled == false else {
                return
            }

            action()
        }
    }

    deinit {
        pendingSuccessCollapseTask?.cancel()
        pendingSuccessResetTask?.cancel()
        searchTask?.cancel(); previewTask?.cancel()
    }
}

nonisolated extension Notification.Name {
    static let notchHubClipboardSettings = Notification.Name("NotchHub.clipboard.settings")
}
nonisolated extension ShortcutModifier {
    var eventFlags: NSEvent.ModifierFlags {
        switch self { case .command: return .command; case .option: return .option; case .control: return .control; case .shift: return .shift }
    }
}
