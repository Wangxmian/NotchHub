import AppKit
import Foundation

struct ClipboardPastebackTicket: Equatable {
    var contentHash: String
    var contentType: ClipboardContentType
    var createdAt: Date
}

@MainActor
final class PasteExecutor {
    private let store: ClipboardStore
    private let pasteboardClient: ClipboardPasteboardClient
    private let referenceValidator: ClipboardReferenceValidator

    init(
        store: ClipboardStore,
        pasteboardClient: ClipboardPasteboardClient,
        referenceValidator: ClipboardReferenceValidator? = nil
    ) {
        self.store = store
        self.pasteboardClient = pasteboardClient
        self.referenceValidator = referenceValidator ?? ClipboardReferenceValidator()
    }

    func write(item: ClipboardHistoryItem, removeFormatting: Bool = false) throws -> ClipboardPastebackTicket {
        let pasteboardItems: [NSPasteboardItem]
        var resourceLeases: [SecurityScopedResourceLease] = []

        switch item.payload {
        case .inline, .figma, .representations:
            let groups = try store.representationGroups(for: item)
            let hasPlain = groups.flatMap { $0 }.contains { $0.pasteboardType == NSPasteboard.PasteboardType.string.rawValue }
            pasteboardItems = groups.compactMap { group in
                let representations = removeFormatting && hasPlain ? group.filter {
                    $0.pasteboardType == NSPasteboard.PasteboardType.string.rawValue || $0.pasteboardType == NSPasteboard.PasteboardType.fileURL.rawValue
                } : group
                guard !representations.isEmpty else { return nil }
                let value = NSPasteboardItem()
                for representation in representations {
                    value.setData(representation.data, forType: .init(representation.pasteboardType))
                }
                value.setString("", forType: .init("io.github.Wangxmian.NotchHub.clipboard"))
                return value
            }
        case let .fileReferences(references):
            let resolvedURLs = try referenceValidator.validate(references)
            resourceLeases = resolvedURLs.map(SecurityScopedResourceLease.init(url:))
            pasteboardItems = resolvedURLs.map { url in
                let pasteboardItem = NSPasteboardItem()
                pasteboardItem.setString(url.absoluteString, forType: .fileURL)
                return pasteboardItem
            }
        }

        try withExtendedLifetime(resourceLeases) {
            try pasteboardClient.write(items: pasteboardItems)
        }

        return ClipboardPastebackTicket(
            contentHash: item.contentHash,
            contentType: item.contentType,
            createdAt: Date()
        )
    }
}
