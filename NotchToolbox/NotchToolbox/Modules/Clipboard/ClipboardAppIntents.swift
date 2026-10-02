import AppIntents
import Foundation

@MainActor enum ClipboardIntentRegistry {
    static weak var model: ClipboardViewModel?
    static func modelOrThrow() throws -> ClipboardViewModel {
        guard let model else { throw ClipboardIntentError.unavailable }; return model
    }
    static func item(number: Int) throws -> ClipboardHistoryItem {
        let items = try modelOrThrow().core.sortedHistory
        guard number > 0 && number <= items.count else { throw ClipboardIntentError.notFound }
        return items[number-1]
    }
}
nonisolated enum ClipboardIntentError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable, notFound
    var localizedStringResource: LocalizedStringResource {
        switch self { case .unavailable: return "NotchHub clipboard is unavailable"; case .notFound: return "Clipboard item not found" }
    }
}
struct NotchHubClipboardEntity: TransientAppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "NotchHub clipboard item")
    @Property(title: "Text") var text: String?
    @Property(title: "HTML") var html: String?
    @Property(title: "Rich Text") var richText: String?
    @Property(title: "Image") var image: URL?
    @Property(title: "File") var file: URL?
    var displayRepresentation: DisplayRepresentation { .init(title: "NotchHub clipboard item") }
}
struct GetNotchHubClipboard: AppIntent {
    static var title: LocalizedStringResource = "Get NotchHub Clipboard Item"
    static var description = IntentDescription("Get text, HTML, rich text, an image or a file from NotchHub clipboard history.")
    @Parameter(title: "Selected", default: true) var selected: Bool
    @Parameter(title: "Number", default: 1) var number: Int
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<NotchHubClipboardEntity> {
        let model = try ClipboardIntentRegistry.modelOrThrow()
        let item: ClipboardHistoryItem
        if selected { guard let current = model.selectedItem else { throw ClipboardIntentError.notFound }; item = current }
        else { item = try ClipboardIntentRegistry.item(number: number) }
        let output = NotchHubClipboardEntity()
        let reps = try model.core.representationGroups(item).flatMap { $0 }
        output.text = reps.first { $0.pasteboardType == "public.utf8-plain-text" }.flatMap { String(data: $0.data, encoding: .utf8) }
        output.html = reps.first { $0.pasteboardType == "public.html" }.flatMap { String(data: $0.data, encoding: .utf8) }
        output.richText = reps.first { $0.pasteboardType == "public.rtf" }.flatMap { String(data: $0.data, encoding: .utf8) }
        if let data = try model.core.imageData(item) {
            let url = FileManager.default.temporaryDirectory.appending(path: "NotchHub-Clipboard-\(UUID()).image")
            try data.write(to: url, options: .atomic); output.image = url
        }
        if case let .fileReferences(references) = item.payload { output.file = try ClipboardReferenceValidator().validate(references).first }
        return .result(value: output)
    }
}
struct SelectNotchHubClipboard: AppIntent {
    static var title: LocalizedStringResource = "Select NotchHub Clipboard Item"
    @Parameter(title: "Number", default: 1) var number: Int
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let model = try ClipboardIntentRegistry.modelOrThrow(); let item = try ClipboardIntentRegistry.item(number: number)
        model.perform(item.id, action: ClipboardActionResolver.resolve([], preferences: model.preferences))
        return .result(value: item.title)
    }
}
struct DeleteNotchHubClipboard: AppIntent {
    static var title: LocalizedStringResource = "Delete NotchHub Clipboard Item"
    @Parameter(title: "Number", default: 1) var number: Int
    @MainActor func perform() async throws -> some IntentResult {
        let model = try ClipboardIntentRegistry.modelOrThrow(); let item = try ClipboardIntentRegistry.item(number: number)
        try model.core.delete(item.id); return .result()
    }
}
struct ClearNotchHubClipboard: AppIntent {
    static var title: LocalizedStringResource = "Clear NotchHub Clipboard History"
    static var description = IntentDescription("Clear ordinary history while keeping pinned items.")
    @MainActor func perform() async throws -> some IntentResult {
        let model = try ClipboardIntentRegistry.modelOrThrow()
        if !model.preferences.suppressClearAlert { try await requestConfirmation() }
        try model.core.clear(); return .result()
    }
}
