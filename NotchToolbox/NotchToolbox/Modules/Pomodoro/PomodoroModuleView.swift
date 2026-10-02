import SwiftUI

struct PomodoroModuleView: View {
    let context: NotchModuleContext
    @ObservedObject var viewModel: PomodoroViewModel
    @State private var draft = ""
    @State private var editingTaskID: UUID?
    @State private var editingEstimate = 1
    @State private var showsRecords = false
    @State private var showsCompleted = false
    @FocusState private var inputFocused: Bool

    private let accent = Color(red: 1, green: 0.42, blue: 0.32)
    private var pendingTasks: [PomodoroTask] { viewModel.taskState.tasks.filter { !$0.isCompleted } }
    private var completedTasks: [PomodoroTask] { viewModel.taskState.tasks.filter { $0.isCompleted } }

    var body: some View {
        HStack(spacing: 20) {
            timerColumn
                .frame(width: 184)
            Rectangle().fill(.white.opacity(0.10)).frame(width: 1)
            taskColumn
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: 536, height: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.setRefreshVisible(true) }
        .onDisappear {
            viewModel.setRefreshVisible(false)
            viewModel.isTaskInputFocused = false
        }
        .onChange(of: inputFocused) { viewModel.isTaskInputFocused = $0 }
    }

    private var timerColumn: some View {
        VStack(spacing: 13) {
            HStack(spacing: 5) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(viewModel.presentation.phase == .breakTime ? "休息时间" : "当前专注")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            Text(viewModel.currentTaskTitle ?? "自由专注")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1).help(viewModel.currentTaskTitle ?? "无需选择任务，也可以开始专注")
            PomodoroTimerRingView(presentation: viewModel.presentation,
                                  onPrimaryAction: viewModel.performPrimaryAction)
            if viewModel.presentation.showsDurationOptions {
                PomodoroDurationPickerView(presentation: viewModel.presentation,
                                           onSelect: viewModel.selectDuration(seconds:))
            } else if let title = viewModel.presentation.secondaryActionTitle {
                PomodoroActionButton(title: title, width: 100, height: 31,
                                     background: .white.opacity(0.08), foreground: .white.opacity(0.7),
                                     action: viewModel.performSecondaryAction)
            }
            Text(viewModel.presentation.footerText)
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            if viewModel.selectedTaskID != nil && viewModel.canSelectTask {
                Button("切换为自由专注") { viewModel.selectTask(nil) }
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
    }

    private var taskColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Button { showsRecords = false } label: {
                    Text("待办 \(pendingTasks.count)").foregroundStyle(showsRecords ? .white.opacity(0.4) : .white)
                }
                Button { showsRecords = true; inputFocused = false } label: {
                    Text("专注记录").foregroundStyle(showsRecords ? .white : .white.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: .semibold)).buttonStyle(.plain)

            if showsRecords {
                recordsList
            } else {
                HStack(spacing: 6) {
                    TextField(editingTaskID == nil ? "添加待办，回车保存" : "编辑任务名称", text: $draft)
                        .textFieldStyle(.plain).font(.system(size: 12)).focused($inputFocused)
                        .onSubmit(saveDraft)
                        .accessibilityIdentifier("pomodoro.taskInput")
                    Button(action: saveDraft) {
                        Image(systemName: editingTaskID == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(accent).font(.system(size: 17))
                    }
                    .buttonStyle(.plain).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help(editingTaskID == nil ? "添加任务" : "保存修改")
                    if editingTaskID != nil {
                        Button { editingTaskID = nil; draft = ""; inputFocused = false } label: {
                            Image(systemName: "xmark").font(.system(size: 10))
                        }.buttonStyle(.plain).help("取消编辑")
                    }
                }
                .padding(10).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        if pendingTasks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checklist").font(.system(size: 24)).foregroundStyle(accent.opacity(0.7))
                                Text("写下一件事，开始一轮专注")
                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                            }.frame(maxWidth: .infinity).padding(.vertical, 25)
                        }
                        ForEach(pendingTasks) { task in
                            taskRow(task)
                                .draggable(task.id.uuidString)
                                .dropDestination(for: String.self) { values, _ in
                                    guard let value = values.first, let id = UUID(uuidString: value),
                                          pendingTasks.contains(where: { $0.id == id }) else { return false }
                                    viewModel.moveTask(id, before: task.id)
                                    return true
                                }
                        }
                        if !completedTasks.isEmpty {
                            Button { showsCompleted.toggle() } label: {
                                Label("已完成 \(completedTasks.count)", systemImage: showsCompleted ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                            }.buttonStyle(.plain).padding(.vertical, 6)
                            if showsCompleted {
                                ForEach(completedTasks) { task in taskRow(task) }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if let error = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 5) {
                    Text(error).font(.system(size: 10)).foregroundStyle(accent).lineLimit(2)
                    Spacer(minLength: 0)
                    Button { viewModel.errorMessage = nil } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                        .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func taskRow(_ task: PomodoroTask) -> some View {
        let count = viewModel.taskState.completedPomodoros(for: task.id)
        let selected = viewModel.selectedTaskID == task.id
        return HStack(spacing: 8) {
            Button { viewModel.toggleTask(task.id) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16)).foregroundStyle(task.isCompleted ? accent : .white.opacity(0.45))
            }
            .buttonStyle(.plain).help(task.isCompleted ? "恢复待办" : "标记任务完成")
            Button { if !task.isCompleted { viewModel.selectTask(task.id) } } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .strikethrough(task.isCompleted).lineLimit(1)
                        .foregroundStyle(task.isCompleted ? .white.opacity(0.35) : .white.opacity(0.9))
                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.system(size: 9))
                        Text(task.estimatedPomodoros > 0 ? "\(count) / \(task.estimatedPomodoros) 番茄" : "\(count) 个番茄")
                            .font(.system(size: 9))
                        if selected { Text("· 当前任务").font(.system(size: 9)) }
                    }.foregroundStyle(selected ? accent : .white.opacity(0.4))
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help(task.title)
            if !task.isCompleted && viewModel.canSelectTask {
                Button { inputFocused = false; viewModel.startTask(task.id) } label: {
                    Image(systemName: "play.fill").font(.system(size: 10)).foregroundStyle(accent)
                        .frame(width: 24, height: 28)
                }.buttonStyle(.plain).help("开始这个任务的专注")
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 9)
        .background(selected ? accent.opacity(0.10) : .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 9))
        .contextMenu {
            Button("编辑任务") {
                showsRecords = false; editingTaskID = task.id; editingEstimate = task.estimatedPomodoros
                draft = task.title; inputFocused = true
            }
            Menu("预计番茄数") {
                ForEach([0, 1, 2, 3, 4, 6, 8], id: \.self) { estimate in
                    Button(estimate == 0 ? "不设置" : "\(estimate) 个番茄") {
                        _ = viewModel.updateTask(task.id, title: task.title, estimate: estimate)
                    }
                }
            }
            Button(task.isCompleted ? "恢复待办" : "标记完成") { viewModel.toggleTask(task.id) }
            Divider()
            Button("删除任务", role: .destructive) { viewModel.deleteTask(task.id) }
        }
    }

    private var recordsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.taskState.records.isEmpty {
                    Text("完成一轮专注后，记录会出现在这里。")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).padding(.top, 20)
                }
                ForEach(viewModel.taskState.records.reversed()) { record in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "stop.circle")
                            .foregroundStyle(record.isCompleted ? accent : .white.opacity(0.4))
                            .font(.system(size: 13))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.taskTitle ?? "自由专注").font(.system(size: 12)).lineLimit(1)
                            Text(record.endedAt, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(record.focusedSeconds / 60) 分钟").font(.system(size: 11))
                            Text(record.isCompleted ? "完成一轮" : "提前结束")
                                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                        }
                    }.padding(9).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }.scrollIndicators(.hidden)
    }

    private func saveDraft() {
        let succeeded: Bool
        if let id = editingTaskID {
            succeeded = viewModel.updateTask(id, title: draft, estimate: editingEstimate)
        } else {
            succeeded = viewModel.addTask(title: draft)
        }
        if succeeded { draft = ""; editingTaskID = nil }
    }
}

private struct PomodoroTimerRingView: View {
    let presentation: PomodoroPresentation
    let onPrimaryAction: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 5)

            Circle()
                .trim(from: 0, to: presentation.progress)
                .stroke(
                    .white.opacity(0.72),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(presentation.progress > 0 ? 1 : 0)

            Text(presentation.timeText)
                .font(.system(size: PomodoroTimerTextMetrics.fontSize, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .monospacedDigit()
                .frame(height: PomodoroTimerTextMetrics.lineHeight)
                .position(x: 60, y: PomodoroTimerTextMetrics.centerY)

            if presentation.showsPrimaryAction {
                PomodoroActionButton(
                    title: presentation.primaryActionTitle,
                    width: 68,
                    height: 26,
                    background: Color(red: 0.102, green: 0.102, blue: 0.102),
                    foreground: .white.opacity(0.7),
                    action: onPrimaryAction
                )
                .position(x: 60, y: PomodoroTimerTextMetrics.buttonCenterY)
            }
        }
        .frame(width: 120, height: 120)
    }
}

private struct PomodoroDurationPickerView: View {
    let presentation: PomodoroPresentation
    let onSelect: (Int) -> Void

    @State private var hoveredSeconds: Int?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(presentation.durationOptions, id: \.self) { seconds in
                Button {
                    onSelect(seconds)
                } label: {
                    Text(PomodoroPresentation.durationOptionTitle(seconds: seconds))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .monospacedDigit()
                        .frame(
                            width: PomodoroDurationTabMetrics.segmentWidth(isLast: isLast(seconds)),
                            height: PomodoroDurationTabMetrics.segmentHeight
                        )
                        .background {
                            RoundedRectangle(
                                cornerRadius: PomodoroDurationTabMetrics.selectedCornerRadius,
                                style: .continuous
                            )
                            .fill(backgroundColor(for: seconds))
                        }
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    hoveredSeconds = isHovering ? seconds : (hoveredSeconds == seconds ? nil : hoveredSeconds)
                }
            }
        }
        .padding(PomodoroDurationTabMetrics.containerPadding)
        .frame(
            width: PomodoroDurationTabMetrics.containerWidth(optionCount: presentation.durationOptions.count),
            height: PomodoroDurationTabMetrics.containerHeight
        )
        .background {
            RoundedRectangle(
                cornerRadius: PomodoroDurationTabMetrics.containerCornerRadius,
                style: .continuous
            )
                .fill(.white.opacity(0.1))
        }
        .animation(.easeOut(duration: 0.12), value: hoveredSeconds)
    }

    private func isLast(_ seconds: Int) -> Bool {
        seconds == presentation.durationOptions.last
    }

    private func backgroundColor(for seconds: Int) -> Color {
        if seconds == presentation.selectedDurationSeconds {
            return .black
        }

        if hoveredSeconds == seconds {
            return .white.opacity(0.1)
        }

        return .clear
    }
}

private struct PomodoroActionButton: View {
    let title: String
    let width: CGFloat
    let height: CGFloat
    let background: Color
    let foreground: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .frame(width: width, height: height)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PomodoroButtonInteractionMetrics.cornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(PomodoroActionButtonStyle(background: background, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: PomodoroButtonInteractionMetrics.animationDuration), value: isHovered)
    }
}

private struct PomodoroActionButtonStyle: ButtonStyle {
    let background: Color
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(
                    cornerRadius: PomodoroButtonInteractionMetrics.cornerRadius,
                    style: .continuous
                )
                .fill(background)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PomodoroButtonInteractionMetrics.cornerRadius,
                        style: .continuous
                    )
                    .fill(.white.opacity(overlayOpacity(isPressed: configuration.isPressed)))
                }
            }
    }

    private func overlayOpacity(isPressed: Bool) -> Double {
        if isPressed {
            return PomodoroButtonInteractionMetrics.activeOverlayOpacity
        }

        if isHovered {
            return PomodoroButtonInteractionMetrics.hoverOverlayOpacity
        }

        return 0
    }
}
