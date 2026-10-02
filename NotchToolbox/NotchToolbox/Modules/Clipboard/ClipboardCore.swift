import AppKit
import Vision
import Combine
import Foundation

@MainActor
final class ClipboardCore: ObservableObject, EnergyManagedTask {
    let id: EnergyTaskID = "clipboard.core"
    let moduleID: NotchModuleID = .clipboard

    @Published private(set) var history: [ClipboardHistoryItem] = []
    private(set) var isPolling = false

    private let pasteboardClient: ClipboardPasteboardClient
    private let sourceApplicationProvider: any ClipboardSourceApplicationProviding
    private let normalizer: ClipboardNormalizer
    private let store: ClipboardStore
    private let settingsStore: SettingsStore
    private let cleanupService: ClipboardCleanupService
    private let pasteExecutor: PasteExecutor
    private let diagnosticsStore: DiagnosticsStore?

    private var pastebackTicket: ClipboardPastebackTicket?
    private var lastKnownChangeCount: Int
    private var pollTimer: Timer?
    private var hasReportedPollFailure = false
    private var settingsSubscription: AnyCancellable?
    private var ownWriteChangeCount: Int?
    private var ocrTasks: [UUID: Task<Void, Never>] = [:]
    private var ocrTail: Task<Void, Never>?
    var preferences: ClipboardPreferences { settingsStore.settings.clipboardPreferences }
    var maxItems: Int { settingsStore.settings.clipboardMaxItems }
    var cleanupPolicy: CleanupPolicy { settingsStore.settings.clipboardAutoCleanupPolicy }
    func setCleanupPolicy(_ policy: CleanupPolicy) throws { try settingsStore.update { $0.clipboardAutoCleanupPolicy = policy } }
    var storageSize: String { store.storageSize }
    func thumbnailURL(_ item: ClipboardHistoryItem) -> URL? { store.thumbnailURL(for: item) }
    var onError: ((String) -> Void)?
    var onNewCapture: ((ClipboardHistoryItem) -> Void)?
    var sortedHistory: [ClipboardHistoryItem] { ClipboardSearchService.sort(history, preferences: preferences) }

    func updatePreferences(_ mutate: (inout ClipboardPreferences) -> Void) throws {
        try settingsStore.update {
            mutate(&$0.clipboardPreferences)
            var p = $0.clipboardPreferences
            p.clipboardCheckInterval = p.clipboardCheckInterval.isFinite ? min(60, max(0.05, p.clipboardCheckInterval)) : 0.5
            p.imageMaxHeight = min(200, max(1, p.imageMaxHeight))
            p.previewDelay = min(100000, max(200, p.previewDelay))
            p.windowWidth = p.windowWidth.isFinite ? min(2000, max(250, p.windowWidth)) : 450
            p.windowHeight = p.windowHeight.isFinite ? min(2000, max(180, p.windowHeight)) : 800
            p.previewWidth = p.previewWidth.isFinite ? min(1200, max(150, p.previewWidth)) : 400
            p.windowX = p.windowX.isFinite ? min(1, max(0, p.windowX)) : 0.5
            p.windowY = p.windowY.isFinite ? min(1, max(0, p.windowY)) : 0.8
            $0.clipboardPreferences = p
        }
    }
    func setMaxItems(_ count: Int) throws {
        try settingsStore.update { $0.clipboardMaxItems = min(999, max(1, count)) }
        try trimHistory()
    }
    func trimHistory() throws {
        var count = 0
        let keep = sortedHistory.filter { item in
            if item.isPinned { return true }; count += 1; return count <= maxItems
        }
        if keep.count != history.count { history = try store.replaceHistory(keep) }
    }
    func mutateItem(_ id: UUID, _ mutate: (inout ClipboardHistoryItem) -> Void) throws {
        var next = history
        guard let i = next.firstIndex(where: { $0.id == id }) else { return }
        mutate(&next[i]); history = try store.replaceHistory(next)
    }
    func togglePin(_ id: UUID) throws {
        let available = availablePinCharacters.filter { key in !history.contains { $0.pinKey == key } }
        try mutateItem(id) { $0.pinKey = $0.isPinned ? nil : available.first ?? "" }
        try trimHistory()
    }
    static let pinCharacters = Array("bcdefghijklmnoprstuxy")
    var availablePinCharacters: [String] {
        let reserved = [preferences.pinShortcut?.keyEquivalent, preferences.deleteShortcut?.keyEquivalent, preferences.previewShortcut?.keyEquivalent].compactMap { $0 }
        return Self.pinCharacters.map(String.init).filter { !reserved.contains($0) }
    }
    func delete(_ id: UUID) throws { history = try store.replaceHistory(history.filter { $0.id != id }) }
    func clear(includingPinned: Bool = false) throws {
        history = try store.replaceHistory(includingPinned ? [] : history.filter(\.isPinned))
        if preferences.clearSystemClipboard { try pasteboardClient.write(items: []) }
    }
    func fullText(_ item: ClipboardHistoryItem) throws -> String {
        let representations = try store.payloadRepresentations(for: item)
        if let plain = representations.first(where: { $0.pasteboardType == "public.utf8-plain-text" }), let text = String(data: plain.data, encoding: .utf8) { return text }
        if let rich = representations.first(where: { $0.pasteboardType == "public.rtf" }), let value = NSAttributedString(rtf: rich.data, documentAttributes: nil) { return value.string }
        if let html = representations.first(where: { $0.pasteboardType == "public.html" }), let value = NSAttributedString(html: html.data, documentAttributes: nil) { return value.string }
        return item.previewText
    }
    func representationGroups(_ item: ClipboardHistoryItem) throws -> [[ClipboardInlineRepresentation]] { try store.representationGroups(for: item) }
    func editText(_ id: UUID, text: String) throws {
        history = try store.editText(id, text: text)
    }
    func imageData(_ item: ClipboardHistoryItem) throws -> Data? {
        try store.payloadRepresentations(for: item).first { representation in
            ["public.png", "public.tiff", "public.jpeg", "public.heic"].contains(representation.pasteboardType)
        }?.data
    }
    func copyQuery(_ text: String) throws {
        let data = Data(text.utf8)
        var item = NSPasteboardItem(); item.setString(text, forType: .string)
        try pasteboardClient.write(items: [item])
        // User-authored query intentionally becomes history, unlike a history pasteback.
        _ = data
        try pollOnce()
    }
    func handleTermination() {
        if preferences.clearOnQuit { do { try clear() } catch { onError?(error.localizedDescription) } }
    }


    init(
        pasteboardClient: any ClipboardPasteboardClient,
        sourceApplicationProvider: any ClipboardSourceApplicationProviding,
        normalizer: ClipboardNormalizer,
        store: ClipboardStore,
        settingsStore: SettingsStore,
        cleanupService: ClipboardCleanupService,
        pasteExecutor: PasteExecutor,
        diagnosticsStore: DiagnosticsStore? = nil
    ) throws {
        self.pasteboardClient = pasteboardClient
        self.sourceApplicationProvider = sourceApplicationProvider
        self.normalizer = normalizer
        self.store = store
        self.settingsStore = settingsStore
        self.cleanupService = cleanupService
        self.pasteExecutor = pasteExecutor
        self.diagnosticsStore = diagnosticsStore
        self.lastKnownChangeCount = pasteboardClient.changeCount
        self.history = try store.loadHistory()
        settingsSubscription = settingsStore.$settings.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.isPolling { self.stopPolling(); self.startPollingIfNeeded() }
                do { try self.trimHistory() } catch { self.onError?(error.localizedDescription) }
                self.objectWillChange.send()
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
        for task in ocrTasks.values { task.cancel() }
    }

    func energyModeDidChange(_ mode: EnergyMode) {
        switch mode {
        case .backgroundCore, .collapsedSummary, .visible, .interactionBoost:
            startPollingIfNeeded()
        case .suspended:
            stopPolling()
        }
    }

    func handleAppDidLaunch() throws {
        _ = try cleanupService.runIfNeeded()
        history = try store.loadHistory()
        for item in history where item.contentType == .image && item.ocrText == nil { scheduleOCR(item) }
    }

    func handleWillSleep() {
        stopPolling()
    }

    func handleDidWake() {
        if let result = try? cleanupService.runIfNeeded(), result.didRun {
            history = (try? store.loadHistory()) ?? history
        }
        lastKnownChangeCount = pasteboardClient.changeCount
        startPollingIfNeeded()
    }

    func paste(item: ClipboardHistoryItem, removeFormatting: Bool = false) throws {
        pastebackTicket = try pasteExecutor.write(item: item, removeFormatting: removeFormatting)
        ownWriteChangeCount = pasteboardClient.changeCount
        history = try store.promote(itemID: item.id, copiedAt: Date())
        ClipboardNotifier.notify(item.title, sound: "knock")
    }

    private func startPollingIfNeeded() {
        guard isPolling == false else {
            return
        }

        isPolling = true
        let timer = Timer.scheduledTimer(withTimeInterval: max(0.05, preferences.clipboardCheckInterval), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollOnceReportingErrors()
            }
        }
        // Let the OS coalesce wake-ups; clipboard polling doesn't need sub-second
        // precision, and a tolerance meaningfully lowers idle energy use.
        timer.tolerance = 0.2
        pollTimer = timer
    }

    private func stopPolling() {
        isPolling = false
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollOnce() throws {
        guard pasteboardClient.changeCount != lastKnownChangeCount else {
            return
        }

        lastKnownChangeCount = pasteboardClient.changeCount
        if ownWriteChangeCount == lastKnownChangeCount { ownWriteChangeCount = nil; pastebackTicket = nil; return }
        // Drop stale suppression tickets before considering a new external copy.
        ownWriteChangeCount = nil; pastebackTicket = nil
        let p = preferences
        guard !p.enabledPasteboardTypes.isEmpty else { return }
        if p.ignoreEvents {
            if p.ignoreOnlyNextEvent { try updatePreferences { $0.ignoreEvents = false; $0.ignoreOnlyNextEvent = false } }
            return
        }
        let sourceApp = sourceApplicationProvider.currentSourceApplication()
        if let bundle = sourceApp?.bundleID {
            let listed = p.ignoredApps.contains(bundle)
            if p.ignoreAllAppsExceptListed ? !listed : listed { return }
        }
        let excluded = Set(p.ignoredPasteboardTypes + ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType"])
        if let live = pasteboardClient as? LiveClipboardPasteboardClient, !excluded.isDisjoint(with: live.availableTypes) { return }
        var snapshot = pasteboardClient.snapshot()
        if !excluded.isDisjoint(with: snapshot.availableTypes) { return }
        let supported = Set(ClipboardPreferences().enabledPasteboardTypes)
        let disabled = supported.subtracting(p.enabledPasteboardTypes)
        snapshot.dataByType = snapshot.dataByType.filter { !disabled.contains($0.key) }
        snapshot.items = snapshot.items.map { $0.filter { !disabled.contains($0.pasteboardType) } }
        if disabled.contains("public.file-url") { snapshot.fileURLs = [] }
        if let text = snapshot.dataByType["public.utf8-plain-text"].flatMap({ String(data: $0, encoding: .utf8) }) {
            for pattern in p.ignoreRegexp {
                if let regex = try? NSRegularExpression(pattern: pattern), regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil { return }
            }
        }
        guard let capture = try normalizer.normalize(snapshot: snapshot, sourceApp: sourceApp) else {
            return
        }

        if pastebackTicket?.contentHash == capture.contentHash {
            pastebackTicket = nil
            return
        }

        let previousIDs = Set(history.map(\.id))
        history = try store.save(capture, maxItems: settingsStore.settings.clipboardMaxItems)
        let cleanup = try cleanupService.runIfNeeded()
        if cleanup.didRun { history = try store.loadHistory() }
        if let newest = history.first {
            onNewCapture?(newest); scheduleOCR(newest)
            if !previousIDs.contains(newest.id) { ClipboardNotifier.notify(newest.title, sound: "write") }
        }
    }

    private func scheduleOCR(_ item: ClipboardHistoryItem) {
        guard item.contentType == .image, item.ocrText == nil, ocrTasks[item.id] == nil else { return }
        let previous = ocrTail
        let task = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled, let self else { return }
            defer { self.ocrTasks[item.id] = nil }
            guard self.history.contains(where: { $0.id == item.id && $0.ocrText == nil }),
                  let data = try? self.imageData(item) else { return }
            let text = await Task.detached(priority: .utility) { () -> String? in
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .fast
                do {
                    try VNImageRequestHandler(data: data).perform([request])
                    return request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                } catch { return nil }
            }.value
            guard !Task.isCancelled else { return }
            if let text { do { try self.mutateItem(item.id) { $0.ocrText = text } } catch { self.onError?(error.localizedDescription) } }
        }
        ocrTasks[item.id] = task
        ocrTail = task
    }

    // A poll failure means captures are being dropped (e.g. the history file
    // can't be written). Report the first failure to diagnostics and stay
    // quiet until a poll succeeds again — a 2 Hz poll must not flood the log.
    func pollOnceReportingErrors() {
        do {
            try pollOnce()
            hasReportedPollFailure = false
        } catch {
            guard !hasReportedPollFailure else {
                return
            }

            hasReportedPollFailure = true
            diagnosticsStore?.record(
                .error,
                message: "Clipboard capture failed: \(error)"
            )
        }
    }
}
