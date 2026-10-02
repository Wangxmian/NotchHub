import CoreGraphics
import Foundation

enum PanelShellPresentation {}

struct PanelMoreModuleItem: Identifiable, Equatable {
    let moduleID: NotchModuleID
    let title: String

    var id: NotchModuleID { moduleID }

    nonisolated static let defaultItems: [PanelMoreModuleItem] = {
        var items = [
            PanelMoreModuleItem(moduleID: .aiChat, title: "AI Chat"),
            PanelMoreModuleItem(moduleID: .clipboard, title: "剪贴板")
        ]
        #if !LOCAL_CUSTOM
        items.append(PanelMoreModuleItem(moduleID: .pomodoro, title: "番茄钟"))
        #endif
        return items
    }()

    nonisolated static func items(for moduleOrder: [NotchModuleID]) -> [PanelMoreModuleItem] {
        PanelShellPresentation.tabLayout(for: moduleOrder).more
    }
}

struct PanelTabLayout: Equatable {
    let primary: [NotchModuleID]
    let more: [PanelMoreModuleItem]
}

extension PanelShellPresentation {
    /// Number of modules pinned as primary tabs in the notch header; the rest go into "更多".
    nonisolated static let primaryTabCount = 2

    nonisolated static func title(for moduleID: NotchModuleID) -> String {
        switch moduleID {
        case .music:
            return "音乐"
        case .fileStash:
            return "文件"
        case .aiChat:
            return "AI Chat"
        case .clipboard:
            return "剪贴板"
        case .pomodoro:
            return "番茄钟"
        case .settings:
            return "设置"
        }
    }

    /// The navigation modules (everything except settings) in the configured order,
    /// with any missing modules appended in their canonical order so the layout is always complete.
    nonisolated static func navigationModules(for moduleOrder: [NotchModuleID]) -> [NotchModuleID] {
        #if LOCAL_CUSTOM
        // Replace the old Files slot even when upgrading existing saved orders.
        let navModules: [NotchModuleID] = [.music, .pomodoro, .aiChat, .clipboard]
        let configured = moduleOrder.map { $0 == .fileStash ? .pomodoro : $0 }
        #else
        let navModules = NotchModuleID.allCases.filter { $0 != .settings }
        let configured = moduleOrder
        #endif
        var ordered: [NotchModuleID] = []
        for moduleID in configured where navModules.contains(moduleID) && !ordered.contains(moduleID) {
            ordered.append(moduleID)
        }
        return ordered + navModules.filter { !ordered.contains($0) }
    }

    /// Maps the configured module order onto the notch header layout:
    /// the first `primaryTabCount` modules become primary tabs, the remainder go into "更多".
    nonisolated static func tabLayout(for moduleOrder: [NotchModuleID]) -> PanelTabLayout {
        let modules = navigationModules(for: moduleOrder)
        let primary = Array(modules.prefix(primaryTabCount))
        let more = modules.dropFirst(primaryTabCount).map { moduleID in
            PanelMoreModuleItem(moduleID: moduleID, title: title(for: moduleID))
        }
        return PanelTabLayout(primary: primary, more: more)
    }

    nonisolated static func isMoreSelected(activeModule: NotchModuleID, layout: PanelTabLayout) -> Bool {
        layout.more.contains { $0.moduleID == activeModule }
    }
}

extension PanelShellPresentation {
    static func bodySize(for moduleID: NotchModuleID) -> CGSize {
        switch moduleID {
        case .music:
            return CGSize(width: 580, height: 280)
        case .fileStash:
            return FileStashModuleLayout.panelBodySize
        case .aiChat:
            return CGSize(width: 580, height: 280)
        case .clipboard:
            return ClipboardModuleLayout.listPanelBodySize
        case .pomodoro:
            return CGSize(width: 580, height: 384)
        case .settings:
            return CGSize(width: 520, height: 300)
        }
    }
}
