import Foundation

// Search semantics adapted from Maccy 2.7.1 (MIT, Alex Rodionov).
@MainActor
struct ClipboardSearchService {
    struct Result: Identifiable {
        var item: ClipboardHistoryItem
        var ranges: [Range<String.Index>] = []
        var score: Double = 0
        var text: String = ""
        var id: UUID { item.id }
    }
    func search(_ query: String, items: [ClipboardHistoryItem], mode: String, preferences: ClipboardPreferences? = nil) -> [Result] {
        guard !query.isEmpty else { return items.map { item in Result(item: item, text: preferences.map { p in item.displayTitle(p) } ?? item.title) } }
        func simple(_ regexp: Bool) -> [Result] {
            items.compactMap { item in
                let title = preferences.map { item.displayTitle($0) } ?? item.title
                guard let range = title.range(of: query, options: regexp ? .regularExpression : .caseInsensitive) else { return nil }
                return Result(item: item, ranges: [range], text: title)
            }
        }
        func fuzzy() -> [Result] {
            let fuse = Fuse(threshold: 0.7)
            let pattern = fuse.createPattern(from: query)
            return items.compactMap { item in
                let text = String((preferences.map { item.displayTitle($0) } ?? item.title).prefix(5001))
                guard let match = fuse.search(pattern, in: text) else { return nil }
                let ranges = match.ranges.map { range in
                    text.index(text.startIndex, offsetBy: range.lowerBound)..<text.index(text.startIndex, offsetBy: range.upperBound + 1)
                }
                return Result(item: item, ranges: ranges, score: match.score, text: text)
            }.sorted { $0.score < $1.score }
        }
        switch mode {
        case "fuzzy": return fuzzy()
        case "regexp": return simple(true)
        case "mixed":
            let exact = simple(false); if !exact.isEmpty { return exact }
            let regex = simple(true); return regex.isEmpty ? fuzzy() : regex
        default: return simple(false)
        }
    }
    static func sort(_ items: [ClipboardHistoryItem], preferences: ClipboardPreferences) -> [ClipboardHistoryItem] {
        let ordered = items.sorted { a, b in
            switch preferences.sortBy {
            case "firstCopiedAt": return (a.firstCopiedAt ?? a.copiedAt) > (b.firstCopiedAt ?? b.copiedAt)
            case "numberOfCopies": return a.copyCount > b.copyCount
            default: return a.copiedAt > b.copiedAt
            }
        }
        return ordered.filter { preferences.pinTo == "bottom" ? !$0.isPinned : $0.isPinned }
            + ordered.filter { preferences.pinTo == "bottom" ? $0.isPinned : !$0.isPinned }
    }
}
