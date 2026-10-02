import Foundation
import Combine

/// Mirrors Maccy's script-visible preference names in NotchHub's own defaults domain.
/// SettingsStore remains authoritative; changes from defaults are validated and committed there.
@MainActor
final class ClipboardAutomationBridge {
    private let core: ClipboardCore
    private let defaults: UserDefaults
    private var timer: Timer?
    private var subscription: AnyCancellable?
    private var last: [String: NSObject] = [:]
    private let keys = ["clearOnQuit", "clearSystemClipboard", "clipboardCheckInterval", "enabledPasteboardTypes", "highlightMatch", "ignoreAllAppsExceptListed", "ignoreEvents", "ignoreOnlyNextEvent", "ignoreRegexp", "ignoredApps", "ignoredPasteboardTypes", "imageMaxHeight", "menuIcon", "pasteByDefault", "pinTo", "popupPosition", "popupScreen", "openPreviewAutomatically", "previewDelay", "removeFormattingByDefault", "searchMode", "showFooter", "showInStatusBar", "showRecentCopyInMenuBar", "showSearch", "searchVisibility", "showSpecialSymbols", "showTitle", "sortBy", "suppressClearAlert", "showApplicationIcons", "showHexColorSwatch", "previewWidth", "historySize", "windowSize", "windowPosition"]
    init(core: ClipboardCore, defaults: UserDefaults = .standard) {
        self.core = core; self.defaults = defaults
        ingest(keys)
        mirror()
        subscription = core.objectWillChange.sink { [weak self] in DispatchQueue.main.async { self?.mirror() } }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer?.tolerance = 0.5
    }
    private func poll() {
        defaults.synchronize()
        let changed = keys.filter { (defaults.object(forKey: $0) as? NSObject) != last[$0] }
        guard !changed.isEmpty else { return }
        ingest(changed); mirror()
    }
    private func ingest(_ changed: [String]) {
        do {
            var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(core.preferences)) as! [String: Any]
            for key in changed {
                guard let value = defaults.object(forKey: key) else { continue }
                if key == "historySize", let count = value as? Int { try core.setMaxItems(count); continue }
                if key == "windowSize", let size = value as? [String: Double] { object["windowWidth"] = size["width"]; object["windowHeight"] = size["height"]; continue }
                if key == "windowPosition", let point = value as? [String: Double] { object["windowX"] = point["x"]; object["windowY"] = point["y"]; continue }
                object[key] = value
            }
            let p = try JSONDecoder().decode(ClipboardPreferences.self, from: JSONSerialization.data(withJSONObject: object))
            try core.updatePreferences { $0 = p }
        } catch { core.onError?("脚本设置未保存：\(error.localizedDescription)") }
    }
    private func mirror() {
        guard var object = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(core.preferences)) as? [String: Any] else { return }
        object["historySize"] = core.maxItems
        object["windowSize"] = ["width": core.preferences.windowWidth, "height": core.preferences.windowHeight]
        object["windowPosition"] = ["x": core.preferences.windowX, "y": core.preferences.windowY]
        for key in keys {
            if let value = object[key] as? NSObject {
                if (defaults.object(forKey: key) as? NSObject) != value { defaults.set(value, forKey: key) }
                last[key] = value
            }
        }
    }
    deinit { timer?.invalidate() }
}
