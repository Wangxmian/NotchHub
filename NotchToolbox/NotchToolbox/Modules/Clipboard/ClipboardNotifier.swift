import AppKit
import UserNotifications

@MainActor enum ClipboardNotifier {
    static func notify(_ body: String, sound: String) {
        guard Bundle.main.bundleIdentifier != nil, ProcessInfo.processInfo.environment["NOTCHHUB_TEST_DATA_DIR"] == nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
                let content = UNMutableNotificationContent()
                if settings.alertSetting == .enabled { content.body = body }
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                center.add(request) { error in
                    if error == nil && settings.soundSetting == .enabled {
                        Task { @MainActor in NSSound(named: NSSound.Name(sound == "knock" ? "Pop" : "Tink"))?.play() }
                    }
                }
            }
        }
    }
}
