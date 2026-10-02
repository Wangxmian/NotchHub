import Combine
import Foundation

@MainActor
final class PomodoroViewModel: ObservableObject {
    let core: PomodoroCore

    @Published private(set) var presentation: PomodoroPresentation
    @Published private(set) var taskState: PomodoroTaskState
    @Published var errorMessage: String?
    @Published var isTaskInputFocused = false

    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: Timer?
    private var isRefreshVisible = false

    init(core: PomodoroCore) {
        self.core = core
        self.presentation = PomodoroPresentation(core: core)
        self.taskState = core.taskState

        core.$sessionSnapshot
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                self.presentation = PomodoroPresentation(core: core)
                self.updateRefreshTimerState()
            }
            .store(in: &cancellables)
        core.$dailyStats
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                self.presentation = PomodoroPresentation(core: core)
                self.updateRefreshTimerState()
            }
            .store(in: &cancellables)
        core.$taskState
            .sink { [weak self] state in self?.taskState = state }
            .store(in: &cancellables)
        updateRefreshTimerState()
    }

    var currentTaskTitle: String? { core.currentTaskTitle }
    var selectedTaskID: UUID? { core.sessionSnapshot?.taskID }
    var canSelectTask: Bool { core.canSelectTask }

    func addTask(title: String) -> Bool {
        perform { _ = try core.addTask(title: title) }
    }

    func selectTask(_ id: UUID?) { _ = perform { try core.selectTask(id: id) } }
    func toggleTask(_ id: UUID) { _ = perform { try core.toggleTask(id: id) } }
    func deleteTask(_ id: UUID) { _ = perform { try core.deleteTask(id: id) } }
    func moveTask(_ id: UUID, before target: UUID) {
        _ = perform { try core.moveTask(id: id, before: target) }
    }
    func updateTask(_ id: UUID, title: String, estimate: Int) -> Bool {
        perform { try core.updateTask(id: id, title: title, estimatedPomodoros: estimate) }
    }
    func startTask(_ id: UUID) {
        _ = perform {
            try core.selectTask(id: id)
            if core.phase == .breakTime { try core.stop() }
            try core.startFocus()
        }
    }

    @discardableResult
    private func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            errorMessage = nil
            refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            refresh()
            return false
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func refresh() {
        try? core.advanceIfNeeded()
        presentation = PomodoroPresentation(core: core)
        updateRefreshTimerState()
    }

    func setRefreshVisible(_ isVisible: Bool) {
        isRefreshVisible = isVisible
        updateRefreshTimerState()
    }

    func selectDuration(seconds: Int) {
        core.setSelectedFocusDuration(seconds: seconds)
        refresh()
    }

    func performPrimaryAction() {
        _ = perform {
        if core.status == .finishedToast { try core.dismissFinishedToast() }
        switch (core.phase, core.status) {
        case (.focus, .idle):
            try core.startFocus()
        case (.focus, .running), (.breakTime, .running):
            try core.pause()
        case (.focus, .paused), (.breakTime, .paused):
            try core.resume()
        case (.breakTime, .idle):
            try core.startBreak()
        case (_, .finishedToast):
            break
        }

        }
    }

    func performSecondaryAction() {
        _ = perform {
            if core.status == .finishedToast { try core.dismissFinishedToast() }
            try core.stop()
        }
    }

    private func startRefreshTimerIfNeeded() {
        guard refreshTimer == nil else {
            return
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func updateRefreshTimerState() {
        if isRefreshVisible || core.status == .running {
            startRefreshTimerIfNeeded()
        } else {
            stopRefreshTimer()
        }
    }
}
