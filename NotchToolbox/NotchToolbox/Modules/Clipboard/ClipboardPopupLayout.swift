import CoreGraphics
import Foundation

nonisolated struct ClipboardPopupLayout {
    var frame: CGRect
    var previewOnLeft: Bool
    var previewWidth: CGFloat
    static func fit(list: CGRect, screen: CGRect, previewWidth: CGFloat?) -> Self {
        let reserve = previewWidth == nil ? 0 : min(150, screen.width / 2)
        let width = min(max(160, list.width), max(1, screen.width - reserve))
        let extra = previewWidth.map { min(max(150, $0), max(0, screen.width - width)) } ?? 0
        let x = min(max(list.minX, screen.minX), screen.maxX - width)
        let left = extra > 0 && x + width + extra > screen.maxX && x - extra >= screen.minX
        let height = min(max(180, list.height), screen.height)
        let frame = CGRect(x: min(max(left ? x-extra : x, screen.minX), screen.maxX-width-extra),
                           y: min(max(list.minY, screen.minY), screen.maxY-height), width: width+extra, height: height)
        return Self(frame: frame, previewOnLeft: left, previewWidth: extra)
    }
}
