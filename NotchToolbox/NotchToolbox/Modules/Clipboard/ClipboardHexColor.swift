import Foundation

nonisolated struct ClipboardHexColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    static func parse(_ text: String) -> Self? {
        let hex = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard [3, 4, 6, 8].contains(hex.count), let value = Int64(hex, radix: 16) else { return nil }
        let bits = hex.count <= 4 ? 4 : 8
        let mask: Int64 = (1 << bits) - 1
        let hasAlpha = hex.count == 4 || hex.count == 8
        func channel(_ position: Int) -> Double { Double((value >> (position * bits)) & mask) / Double(mask) }
        return Self(red: channel(hasAlpha ? 3 : 2), green: channel(hasAlpha ? 2 : 1),
                    blue: channel(hasAlpha ? 1 : 0), alpha: hasAlpha ? channel(0) : 1)
    }
}
