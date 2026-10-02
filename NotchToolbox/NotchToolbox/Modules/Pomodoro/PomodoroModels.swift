import Foundation

enum PomodoroPhase: String, Codable, Equatable {
    case focus
    case breakTime
}

enum PomodoroStatus: String, Codable, Equatable {
    case idle
    case running
    case paused
    case finishedToast
}

struct PomodoroSessionSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var phase: PomodoroPhase
    var status: PomodoroStatus
    var selectedFocusDurationSeconds: Int
    var breakDurationSeconds: Int
    var startedAt: Date?
    var targetEndAt: Date?
    var remainingWhenPaused: TimeInterval?
    var lastUpdatedAt: Date
    var taskID: UUID? = nil
    var taskTitle: String? = nil
}

struct PomodoroDailyStats: Codable, Equatable {
    var dayKey: String
    var focusedSecondsCompleted: Int
    var lastSessionId: UUID?
}

enum PomodoroError: Error, Equatable {
    case invalidDuration
    case invalidTransition
}

struct PomodoroTask: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var estimatedPomodoros: Int
    var createdAt: Date
    var completedAt: Date?
    var isCompleted: Bool { completedAt != nil }
}

struct PomodoroFocusRecord: Codable, Equatable, Identifiable {
    var id: UUID // Session ID also prevents duplicate recording after restart.
    var taskID: UUID?
    var taskTitle: String?
    var endedAt: Date
    var focusedSeconds: Int
    var isCompleted: Bool
}

struct PomodoroTaskState: Codable, Equatable {
    var tasks: [PomodoroTask] = []
    var records: [PomodoroFocusRecord] = []

    func completedPomodoros(for taskID: UUID) -> Int {
        records.filter { $0.taskID == taskID && $0.isCompleted }.count
    }
}

enum PomodoroTaskError: LocalizedError {
    case emptyTitle, taskUnavailable, activeTaskLocked
    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "请输入任务名称。"
        case .taskUnavailable: return "这个任务已完成或不存在。"
        case .activeTaskLocked: return "请先停止当前计时，再切换、完成或删除当前任务。"
        }
    }
}
