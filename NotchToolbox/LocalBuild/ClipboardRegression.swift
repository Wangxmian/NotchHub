import AppKit
import Foundation
import CoreText

@main struct ClipboardRegression {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileStore = LocalFileStore(baseURL: root)
        let store = try ClipboardStore(fileStore: fileStore)
        let settings = try SettingsStore(storageURL: root.appending(path: "Settings/settings.json"))
        let client = TestPasteboard()
        let source = TestSource()
        let core = try ClipboardCore(pasteboardClient: client, sourceApplicationProvider: source, normalizer: ClipboardNormalizer(), store: store, settingsStore: settings, cleanupService: ClipboardCleanupService(store: store, settingsStore: settings, scheduler: CleanupScheduler()), pasteExecutor: PasteExecutor(store: store, pasteboardClient: client))
        func capture(_ text: String) { client.copy(text); core.pollOnceReportingErrors() }
        capture("first\nline")
        precondition(core.history.count == 1)
        let id = core.history[0].id
        try core.togglePin(id)
        try core.mutateItem(id) { $0.alias = "常用内容" }
        capture("first\nline")
        precondition(core.history.count == 1 && core.history[0].id == id)
        precondition(core.history[0].isPinned && core.history[0].alias == "常用内容" && core.history[0].copyCount == 2)
        let rawText = try core.fullText(core.history[0])
        precondition(rawText == "first\nline")
        try core.setMaxItems(1)
        capture("second"); capture("third")
        precondition(core.history.count == 2 && core.history.contains { $0.id == id })
        try core.clear()
        precondition(core.history.count == 1 && core.history[0].id == id)
        try core.updatePreferences { $0.ignoreEvents = true; $0.ignoreOnlyNextEvent = true }
        capture("ignored once")
        precondition(core.history.count == 1 && !core.preferences.ignoreEvents)
        capture("accepted")
        precondition(core.history.contains { $0.previewText == "accepted" })
        try core.updatePreferences { $0.ignoreRegexp = ["^secret"] }
        capture("secret key")
        precondition(!core.history.contains { $0.previewText == "secret key" })
        source.bundle = "test.private"
        try core.updatePreferences { $0.ignoredApps = ["test.private"] }
        capture("private app")
        precondition(!core.history.contains { $0.previewText == "private app" })
        try core.updatePreferences { $0.ignoreAllAppsExceptListed = true }
        capture("whitelist allowed")
        precondition(core.history.contains { $0.previewText == "whitelist allowed" })
        source.bundle = "test.other"; capture("whitelist denied")
        precondition(!core.history.contains { $0.previewText == "whitelist denied" })
        try core.updatePreferences { $0.ignoreAllAppsExceptListed = false; $0.ignoreRegexp = []; $0.ignoredApps = [] }
        client.types = ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]
        capture("concealed")
        precondition(!core.history.contains { $0.previewText == "concealed" })
        client.types = ["public.utf8-plain-text"]
        let pinned = core.history.first { $0.id == id }!
        try core.paste(item: pinned)
        core.pollOnceReportingErrors()
        precondition(core.history.filter { $0.id == id }.count == 1)
        capture("first\nline")
        precondition(core.history.filter { $0.id == id }.count == 1 && core.history.first { $0.id == id }!.copyCount == 4)
        let enabled = core.preferences.enabledPasteboardTypes
        try core.updatePreferences { $0.enabledPasteboardTypes = [] }
        capture("all formats disabled")
        precondition(!core.history.contains { $0.previewText == "all formats disabled" })
        try core.updatePreferences { $0.enabledPasteboardTypes = enabled }
        capture("first\nline")
        let revisionCount = client.changeCount
        let revisionID = core.history.first!.id
        let revisionCopies = core.history.first!.copyCount
        client.revision = revisionCount; capture("revised source text"); client.revision = nil
        precondition(core.history.first!.id == revisionID && core.history.first!.previewText == "revised source text")
        precondition(core.history.first!.copyCount == revisionCopies + 1 && core.history.first!.isPinned)
        let model = ClipboardViewModel(core: core)
        model.refresh(); model.selectedID = model.results.last?.id
        model.moveSelection(1)
        precondition(model.selectedFooter == 0 && model.selectedID == nil)
        model.moveSelection(1); precondition(model.selectedFooter == 1)
        model.moveSelection(-1); model.moveSelection(-1)
        precondition(model.selectedID == model.results.last?.id && model.selectedFooter == nil)
        ClipboardIntentRegistry.model = model
        for invalid in [0, -1, core.history.count + 1] {
            do { _ = try ClipboardIntentRegistry.item(number: invalid); preconditionFailure("Invalid intent index accepted") }
            catch ClipboardIntentError.notFound {} catch { throw error }
        }
        // Rich text retains all original representations and falls back correctly.
        let text = ClipboardInlineRepresentation(data: Data("A\nB".utf8), pasteboardType: "public.utf8-plain-text", suggestedFileExtension: nil)
        let rtf = ClipboardInlineRepresentation(data: Data(#"{\rtf1 hello}"#.utf8), pasteboardType: "public.rtf", suggestedFileExtension: nil)
        let rich = ClipboardCapture(contentType: .richText, previewText: "A B", contentHash: "rich", capturedAt: Date(), sourceAppBundleID: nil, sourceAppName: nil, payload: .inline(data: rtf.data, pasteboardType: rtf.pasteboardType, suggestedFileExtension: nil), representations: [[text, rtf]])
        let richItem = try store.save(rich, maxItems: 200).first!
        let executor = PasteExecutor(store: store, pasteboardClient: client)
        _ = try executor.write(item: richItem)
        precondition(client.written[0].types.contains(.rtf) && client.written[0].string(forType: .string) == "A\nB")
        _ = try executor.write(item: richItem, removeFormatting: true)
        precondition(!client.written[0].types.contains(.rtf) && client.written[0].string(forType: .string) == "A\nB")
        let imageRep = ClipboardInlineRepresentation(data: Data([1,2,3]), pasteboardType: "public.png", suggestedFileExtension: nil)
        let image = ClipboardCapture(contentType: .image, previewText: "Image", contentHash: "image", capturedAt: Date(), sourceAppBundleID: nil, sourceAppName: nil, payload: .inline(data: imageRep.data, pasteboardType: imageRep.pasteboardType, suggestedFileExtension: nil), representations: [[imageRep]])
        let imageItem = try store.save(image, maxItems: 200).first!
        _ = try executor.write(item: imageItem, removeFormatting: true)
        precondition(client.written[0].types.contains(.png))
        let groups = ClipboardCapture(contentType: .plainText, previewText: "group", contentHash: "groups", capturedAt: Date(), sourceAppBundleID: nil, sourceAppName: nil, payload: .inline(data: text.data, pasteboardType: text.pasteboardType, suggestedFileExtension: nil), representations: [[text], [rtf]])
        let groupItem = try store.save(groups, maxItems: 200).first!
        _ = try executor.write(item: groupItem)
        precondition(client.written.count == 2)
        // Legacy JSON can decode missing metadata and migration creates a backup.
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode([pinned])) as! [[String: Any]]
        for key in ["firstCopiedAt","copyCount","pinKey","alias","ocrText"] { legacy[0].removeValue(forKey: key) }
        let historyURL = fileStore.url(for: .clipboard).appending(path: "history.json")
        try JSONSerialization.data(withJSONObject: legacy).write(to: historyURL)
        let loaded = try store.loadHistory()[0]
        precondition(loaded.copyCount == 1 && !loaded.isPinned && loaded.firstCopiedAt == loaded.copiedAt)
        _ = try store.promote(itemID: loaded.id, copiedAt: Date())
        precondition(FileManager.default.fileExists(atPath: historyURL.deletingLastPathComponent().appending(path: "history-before-maccy-upgrade.json").path))
        let defaults = try JSONDecoder().decode(ClipboardPreferences.self, from: Data("{}".utf8))
        precondition(defaults.searchMode == "exact" && defaults.popupShortcut?.keyEquivalent == "c" && defaults.previewDelay == 1500)
        // Search samples adapted from Maccy SearchTests; scores/ranges use the same Fuse revision.
        func item(_ title: String) -> ClipboardHistoryItem { var value = loaded; value.id = UUID(); value.previewText = title; return value }
        let items = [item("foo bar baz"), item("foo bar zaz"), item("xxx yyy zzz")]
        let search = ClipboardSearchService()
        precondition(search.search("FOO", items: items, mode: "exact").count == 2)
        precondition(search.search("fbb", items: items, mode: "exact").isEmpty)
        let fuzzy = search.search("fbb", items: items, mode: "fuzzy")
        precondition(!fuzzy.isEmpty)
        precondition(search.search("^foo", items: items, mode: "regexp").count == 2)
        precondition(search.search("[", items: items, mode: "regexp").isEmpty)
        precondition(search.search("foo", items: items, mode: "mixed").map(\.id) == search.search("foo", items: items, mode: "exact").map(\.id))
        precondition(search.search("番茄", items: [item("写番茄钟")], mode: "exact").count == 1)
        // Exhaustive action truth table.
        let flags: [NSEvent.ModifierFlags] = [[], .command, .option, [.option,.shift], [.command,.shift]]
        let expected: [[ClipboardAction?]] = [[.copy,.copy,.paste,.pastePlainText,nil], [.copyPlainText,.copy,.pastePlainText,.paste,nil], [.paste,.paste,.copy,nil,.pastePlainText], [.pastePlainText,.pastePlainText,.copy,nil,.paste]]
        for index in 0..<4 {
            var p = ClipboardPreferences(); p.pasteByDefault = index >= 2; p.removeFormattingByDefault = index % 2 == 1
            for (i, flag) in flags.enumerated() { precondition(ClipboardActionResolver.resolve(flag, preferences: p) == expected[index][i]) }
        }
        try core.updatePreferences { $0.clipboardCheckInterval = -1; $0.imageMaxHeight = 999; $0.previewDelay = 0 }
        precondition(core.preferences.clipboardCheckInterval == 0.05 && core.preferences.imageMaxHeight == 200 && core.preferences.previewDelay == 200)
        // Script bridge uses an isolated defaults suite and never changes user history.
        let suite = "NotchHubRegression.\(UUID())"; let ud = UserDefaults(suiteName: suite)!
        ud.set(true, forKey: "ignoreEvents"); let bridge = ClipboardAutomationBridge(core: core, defaults: ud)
        precondition(core.preferences.ignoreEvents)
        withExtendedLifetime(bridge) {}; ud.removePersistentDomain(forName: suite)
        precondition(NotchHubReleaseUpdater.newer("v1.10.0", than: "1.9.0"))
        precondition(!NotchHubReleaseUpdater.newer("v1.2.0", than: "1.3.0"))
        // Geometry covers right-edge reversal, a negative-origin display and oversized preferences.
        let screen = CGRect(x: -1200, y: 0, width: 1200, height: 800)
        let left = ClipboardPopupLayout.fit(list: CGRect(x: -450, y: 0, width: 450, height: 800), screen: screen, previewWidth: 400)
        precondition(left.previewOnLeft && screen.contains(left.frame))
        let wide = ClipboardPopupLayout.fit(list: CGRect(x: 0, y: 900, width: 2000, height: 2000), screen: screen, previewWidth: 1200)
        precondition(screen.contains(wide.frame) && wide.previewWidth > 0)
        let closed = ClipboardPopupLayout.fit(list: left.frame, screen: screen, previewWidth: nil)
        precondition(closed.previewWidth == 0 && screen.contains(closed.frame))
        // Exercise real Vision OCR on a synthetic image and search the recognized content.
        let context = CGContext(data: nil, width: 1000, height: 160, bitsPerComponent: 8, bytesPerRow: 4000,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 160))
        context.textPosition = CGPoint(x: 24, y: 50)
        let label = NSAttributedString(string: "NOTCHHUB OCR TEST", attributes: [
            .init(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 64, nil),
            .init(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)])
        CTLineDraw(CTLineCreateWithAttributedString(label), context)
        let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
        let ocrCapture = ClipboardCapture(contentType: .image, previewText: "OCR", contentHash: "ocr-sample", capturedAt: Date(),
            sourceAppBundleID: nil, sourceAppName: nil, payload: .inline(data: png, pasteboardType: "public.png", suggestedFileExtension: "png"))
        let ocrItem = try store.save(ocrCapture, maxItems: 200).first!
        try core.handleAppDidLaunch()
        for _ in 0..<40 {
            if core.history.first(where: { $0.id == ocrItem.id })?.ocrText != nil { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        let recognized = core.history.first { $0.id == ocrItem.id }!
        precondition(recognized.ocrText?.contains("NOTCHHUB") == true, "Vision OCR failed to recognize sample")
        precondition(search.search("OCR TEST", items: [recognized], mode: "exact").count == 1)
        print("PASS: legacy migration, pin-preserving dedup, limits, clearing, pause/ignore/whitelist, sensitive flags, self-write suppression, raw rich/plain/image and grouped roundtrip, 4 search modes, 20 action combinations, setting bounds, script bridge, footer navigation, intent bounds, screen geometry and real Vision OCR")
    }
}
@MainActor private final class TestPasteboard: ClipboardPasteboardClient {
    var changeCount = 0
    var text = ""
    var types = ["public.utf8-plain-text"]
    var written: [NSPasteboardItem] = []
    var revision: Int?
    func copy(_ value: String) { text = value; changeCount += 1 }
    func snapshot() -> ClipboardPasteboardSnapshot {
        var data = ["public.utf8-plain-text": Data(text.utf8)]
        if let revision { data["x.nspasteboard.ModifiedType"] = Data(String(revision).utf8) }
        return .init(changeCount: changeCount, availableTypes: types, dataByType: data, fileURLs: [])
    }
    func write(items: [NSPasteboardItem]) throws { written = items; changeCount += 1 }
}
private final class TestSource: ClipboardSourceApplicationProviding {
    var bundle = "test.public"
    func currentSourceApplication() -> ClipboardSourceApplication? { .init(bundleID: bundle, name: bundle) }
}
