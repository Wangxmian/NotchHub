import Foundation

enum ClipboardPayloadDescriptor: Codable, Equatable {
    case inline(fileName: String, pasteboardType: String, suggestedFileExtension: String?)
    case figma([ClipboardStoredRepresentationDescriptor])
    case representations([[ClipboardStoredRepresentationDescriptor]])
    case fileReferences([ClipboardFileReference])

    private enum CodingKeys: String, CodingKey {
        case kind
        case fileName
        case pasteboardType
        case suggestedFileExtension
        case representations
        case fileReferences
    }

    private enum Kind: String, Codable {
        case inline
        case figma
        case representations
        case fileReferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .inline:
            self = .inline(
                fileName: try container.decode(String.self, forKey: .fileName),
                pasteboardType: try container.decode(String.self, forKey: .pasteboardType),
                suggestedFileExtension: try container.decodeIfPresent(
                    String.self,
                    forKey: .suggestedFileExtension
                )
            )
        case .figma:
            self = .figma(
                try container.decode(
                    [ClipboardStoredRepresentationDescriptor].self,
                    forKey: .representations
                )
            )
        case .representations:
            self = .representations(try container.decode([[ClipboardStoredRepresentationDescriptor]].self, forKey: .representations))
        case .fileReferences:
            self = .fileReferences(
                try container.decode([ClipboardFileReference].self, forKey: .fileReferences)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .inline(fileName, pasteboardType, suggestedFileExtension):
            try container.encode(Kind.inline, forKey: .kind)
            try container.encode(fileName, forKey: .fileName)
            try container.encode(pasteboardType, forKey: .pasteboardType)
            try container.encodeIfPresent(
                suggestedFileExtension,
                forKey: .suggestedFileExtension
            )
        case let .figma(representations):
            try container.encode(Kind.figma, forKey: .kind)
            try container.encode(representations, forKey: .representations)
        case let .representations(groups):
            try container.encode(Kind.representations, forKey: .kind)
            try container.encode(groups, forKey: .representations)
        case let .fileReferences(fileReferences):
            try container.encode(Kind.fileReferences, forKey: .kind)
            try container.encode(fileReferences, forKey: .fileReferences)
        }
    }
}

struct ClipboardHistoryItem: Codable, Equatable, Identifiable {
    var id: UUID
    var contentType: ClipboardContentType
    var previewText: String
    var contentHash: String
    var copiedAt: Date
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var payload: ClipboardPayloadDescriptor
    var thumbnail: ClipboardThumbnailDescriptor?
    var firstCopiedAt: Date? = nil
    var copyCount: Int = 1
    var pinKey: String? = nil
    var alias: String? = nil
    var ocrText: String? = nil
}


extension ClipboardHistoryItem {
    var isPinned: Bool { pinKey != nil }
    var title: String { (alias ?? ocrText ?? String(previewText.prefix(1000))).removingScalarsUnsafeForTitleLayout() }
    func displayTitle(_ p: ClipboardPreferences) -> String {
        if alias != nil || ocrText != nil { return title }
        if !p.showSpecialSymbols { return title.trimmingCharacters(in: .whitespacesAndNewlines) }
        var result = title
        if let range = result.range(of: "^ +", options: .regularExpression) { result = result.replacingOccurrences(of: " ", with: "·", range: range) }
        if let range = result.range(of: " +$", options: .regularExpression) { result = result.replacingOccurrences(of: " ", with: "·", range: range) }
        return result.replacingOccurrences(of: "\n", with: "⏎").replacingOccurrences(of: "\t", with: "⇥")
    }
    private enum MetadataKeys: String, CodingKey {
        case id, contentType, previewText, contentHash, copiedAt, sourceAppBundleID, sourceAppName, payload, thumbnail
        case firstCopiedAt, copyCount, pinKey, alias, ocrText
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: MetadataKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        contentType = try c.decode(ClipboardContentType.self, forKey: .contentType)
        previewText = try c.decode(String.self, forKey: .previewText)
        contentHash = try c.decode(String.self, forKey: .contentHash)
        copiedAt = try c.decode(Date.self, forKey: .copiedAt)
        sourceAppBundleID = try c.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        sourceAppName = try c.decodeIfPresent(String.self, forKey: .sourceAppName)
        payload = try c.decode(ClipboardPayloadDescriptor.self, forKey: .payload)
        thumbnail = try c.decodeIfPresent(ClipboardThumbnailDescriptor.self, forKey: .thumbnail)
        firstCopiedAt = try c.decodeIfPresent(Date.self, forKey: .firstCopiedAt) ?? copiedAt
        copyCount = try c.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1
        pinKey = try c.decodeIfPresent(String.self, forKey: .pinKey)
        alias = try c.decodeIfPresent(String.self, forKey: .alias)
        ocrText = try c.decodeIfPresent(String.self, forKey: .ocrText)
    }
}
