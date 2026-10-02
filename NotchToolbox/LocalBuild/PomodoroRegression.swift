import Foundation

@main
struct PomodoroRegression {
    @MainActor static func main() throws {
        let layout = PanelShellPresentation.tabLayout(for: NotchModuleID.allCases)
        precondition(layout.primary == [.music, .pomodoro])
        precondition(layout.more.map(\.moduleID) == [.aiChat, .clipboard])
        let migratedOrder = PanelShellPresentation.navigationModules(for: [.music, .fileStash, .aiChat, .clipboard, .pomodoro, .settings])
        precondition(migratedOrder == [.music, .pomodoro, .aiChat, .clipboard])
        let custom = PanelShellPresentation.navigationModules(for: [.clipboard, .fileStash, .pomodoro, .music])
        precondition(custom == [.clipboard, .pomodoro, .music, .aiChat])
        precondition(!PanelShellPresentation.navigationModules(for: []).contains(.fileStash))
        precondition(PanelMoreModuleItem.defaultItems.map(\.moduleID) == [.aiChat, .clipboard])
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = try PomodoroSessionStore(fileStore: LocalFileStore(baseURL: root))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let core = try PomodoroCore(store: store, nowProvider: { now }, calendar: calendar)
        let a = try core.addTask(title: "  写设计稿  ", estimatedPomodoros: 3)
        let b = try core.addTask(title: "阅读论文", estimatedPomodoros: 2)
        precondition(core.taskState.tasks.first?.title == "写设计稿")
        do { _ = try core.addTask(title: "  "); fatalError("empty title accepted") }
        catch PomodoroTaskError.emptyTitle {}
        try core.moveTask(id: b, before: a)
        precondition(core.taskState.tasks.first?.id == b)
        try core.selectTask(id: a)
        try core.startFocus()
        let running = core.sessionSnapshot!
        do { try core.selectTask(id: b); fatalError("active task changed") }
        catch PomodoroTaskError.activeTaskLocked {}
        do { try core.toggleTask(id: a); fatalError("active task completed") }
        catch PomodoroTaskError.activeTaskLocked {}
        do { try core.deleteTask(id: a); fatalError("active task deleted") }
        catch PomodoroTaskError.activeTaskLocked {}
        now = now.addingTimeInterval(120)
        try core.pause()
        now = now.addingTimeInterval(60)
        try core.resume()
        precondition(core.remainingSeconds() == 1_380)
        try core.updateTask(id: a, title: "新设计稿", estimatedPomodoros: 4)
        now = now.addingTimeInterval(1_381)
        try core.advanceIfNeeded()
        try core.advanceIfNeeded()
        precondition(core.taskState.completedPomodoros(for: a) == 1)
        precondition(core.taskState.records.count == 1)
        precondition(core.taskState.records.first?.taskTitle == "写设计稿")
        precondition(core.taskState.records.first?.focusedSeconds == 1_500)
        precondition(core.todayFocusedSeconds() == 1_500)
        precondition(core.currentTaskTitle == "新设计稿")
        try core.dismissFinishedToast()
        precondition(core.sessionSnapshot?.taskID == a)
        try core.startBreak()
        now = now.addingTimeInterval(301)
        try core.advanceIfNeeded()
        try core.dismissFinishedToast()
        precondition(core.phase == .focus && core.status == .idle)
        precondition(core.taskState.records.count == 1)
        try core.startFocus()
        now = now.addingTimeInterval(90)
        try core.stop()
        precondition(core.taskState.records.count == 2)
        precondition(core.taskState.records.last?.focusedSeconds == 90)
        precondition(core.taskState.records.last?.isCompleted == false)
        precondition(core.taskState.completedPomodoros(for: a) == 1)
        try core.toggleTask(id: a)
        precondition(core.sessionSnapshot?.taskID == nil)
        try core.toggleTask(id: a)
        try core.selectTask(id: b)
        let restored = try PomodoroCore(store: store, nowProvider: { now }, calendar: calendar)
        precondition(restored.taskState == core.taskState)
        precondition(restored.sessionSnapshot?.taskID == b)
        try core.deleteTask(id: a)
        precondition(core.taskState.records.count == 2)
        precondition(core.taskState.records.first?.taskTitle == "写设计稿")
        try core.selectTask(id: nil)
        try core.startFocus()
        now = now.addingTimeInterval(1_501)
        try core.advanceIfNeeded()
        precondition(core.taskState.records.last?.taskID == nil)
        precondition(core.taskState.records.last?.isCompleted == true)
        // Simulate a crash after the record write but before the session write.
        var expired = running
        expired.targetEndAt = now.addingTimeInterval(-1)
        try store.saveSession(expired)
        let recovered = try PomodoroCore(store: store, nowProvider: { now }, calendar: calendar)
        precondition(recovered.taskState.records.count == 3)
        // Existing installations have session JSON without task fields.
        var legacy = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appending(path: "Pomodoro/session.json"))) as! [String: Any]
        legacy.removeValue(forKey: "taskID")
        legacy.removeValue(forKey: "taskTitle")
        try JSONSerialization.data(withJSONObject: legacy).write(to: root.appending(path: "Pomodoro/session.json"))
        let migrated = try store.loadSession()
        precondition(migrated?.taskID == nil)
        print("PASS: task CRUD, ordering, task locking, pause/resume, full and partial records, break continuity, persistence, deletion history, free focus, crash deduplication, legacy migration")
    }
}
