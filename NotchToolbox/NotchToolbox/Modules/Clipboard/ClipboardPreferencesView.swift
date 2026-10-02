import UniformTypeIdentifiers
import AppKit
import SwiftUI

struct ClipboardPreferencesView: View {
    @ObservedObject var model: ClipboardViewModel
    @State private var category = 0
    @State private var rule = ""
    @State private var validationError: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("剪贴板设置", selection: $category) {
                Text("通用").tag(0); Text("存储").tag(1); Text("外观").tag(2)
                Text("固定").tag(3); Text("忽略").tag(4); Text("高级").tag(5)
            }.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch category {
                    case 0: general
                    case 1: storage
                    case 2: appearance
                    case 3: pins
                    case 4: ignore
                    default: advanced
                    }
                }.padding(.vertical, 8)
            }
            if let error = validationError ?? model.lastPasteError { Text(error).font(.caption).foregroundStyle(.orange) }
        }.padding(20)
        .onAppear { model.refresh() }
    }
    private func binding<T>(_ path: WritableKeyPath<ClipboardPreferences, T>) -> Binding<T> {
        Binding(get: { model.preferences[keyPath: path] }, set: { value in model.updatePreferences { $0[keyPath: path] = value } })
    }
    private func toggle(_ title: String, _ path: WritableKeyPath<ClipboardPreferences, Bool>) -> some View {
        Toggle(title, isOn: binding(path))
    }
    private func picker(_ title: String, _ path: WritableKeyPath<ClipboardPreferences, String>, _ options: [(String, String)]) -> some View {
        Picker(title, selection: binding(path)) { ForEach(options, id: \.0) { Text($0.1).tag($0.0) } }
    }
    private func integer(_ title: String, _ path: WritableKeyPath<ClipboardPreferences, Int>, range: ClosedRange<Int>) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: binding(path), format: .number).frame(width: 80)
            Stepper("", value: binding(path), in: range).labelsHidden() }
    }
    private var general: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷键").font(.headline)
            ClipboardShortcutRecorder(title: "打开剪贴板", value: binding(\.popupShortcut), global: true)
            ClipboardShortcutRecorder(title: "固定 / 取消固定", value: binding(\.pinShortcut))
            ClipboardShortcutRecorder(title: "删除记录", value: binding(\.deleteShortcut))
            ClipboardShortcutRecorder(title: "显示预览", value: binding(\.previewShortcut))
            picker("搜索方式", \.searchMode, [("exact","子串"),("fuzzy","模糊"),("regexp","正则"),("mixed","混合")])
            toggle("选择后自动粘贴", \.pasteByDefault)
            toggle("默认移除格式", \.removeFormattingByDefault)
            Text(actionDescription).font(.caption).foregroundStyle(.secondary)
            toggle("快捷键打开刘海面板", \.openInNotch)
            Text("登录启动与软件更新使用 NotchHub 通用设置。通知与声音由系统管理。").font(.caption)
            Button("通知与声音设置") { if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=io.github.Wangxmian.NotchHub") { NSWorkspace.shared.open(url) } }
        }
    }
    private var actionDescription: String {
        if !model.preferences.pasteByDefault { return model.preferences.removeFormattingByDefault ? "Enter 去格式复制；⌥Enter 去格式粘贴；⌥⇧Enter 保留格式粘贴。" : "Enter 复制；⌥Enter 粘贴；⌥⇧Enter 去格式粘贴。" }
        return model.preferences.removeFormattingByDefault ? "Enter 去格式粘贴；⌥Enter 复制；⌘⇧Enter 保留格式粘贴。" : "Enter 粘贴；⌥Enter 复制；⌘⇧Enter 去格式粘贴。"
    }
    private func types(_ title: String, _ values: [String]) -> some View {
        Toggle(title, isOn: Binding(get: { Set(values).isSubset(of: Set(model.preferences.enabledPasteboardTypes)) }, set: { enabled in
            model.updatePreferences { prefs in
                let current = Set(prefs.enabledPasteboardTypes)
                prefs.enabledPasteboardTypes = Array(enabled ? current.union(values) : current.subtracting(values)).sorted()
            }
        }))
    }
    private var storage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("保存内容").font(.headline)
            types("文本与富文本", ["public.utf8-plain-text","public.rtf","public.html"])
            types("图片", ["public.png","public.tiff","public.jpeg","public.heic"])
            types("文件", ["public.file-url"])
            Stepper("普通历史数量：\(model.core.maxItems)", value: Binding(get: { model.core.maxItems }, set: { value in do { try model.core.setMaxItems(value) } catch { validationError = error.localizedDescription } }), in: 1...999)
            Text("固定项不计入普通历史上限。磁盘占用：\(model.core.storageSize)").font(.caption)
            picker("排序方式", \.sortBy, [("lastCopiedAt","最近复制"),("firstCopiedAt","首次复制"),("numberOfCopies","复制次数")])
            Picker("自动清理（NotchHub 扩展）", selection: Binding(get: { model.core.cleanupPolicy }, set: { policy in do { try model.core.setCleanupPolicy(policy) } catch { validationError = error.localizedDescription } })) {
                Text("不自动").tag(CleanupPolicy.none); Text("每日").tag(CleanupPolicy.daily); Text("每周").tag(CleanupPolicy.weekly); Text("每月").tag(CleanupPolicy.monthly)
            }
        }
    }
    private var appearance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("浮动面板位置与尺寸").font(.headline)
            picker("弹出位置", \.popupPosition, [("cursor","鼠标位置"),("statusItem","菜单栏图标"),("window","前台窗口中央"),("center","屏幕中央"),("lastPosition","上次位置")])
            Picker("屏幕", selection: binding(\.popupScreen)) {
                Text("活动屏幕").tag(0)
                ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in Text(screen.localizedName).tag(index+1) }
            }
            HStack {
                Text("最大尺寸"); TextField("宽", value: binding(\.windowWidth), format: .number); Text("×"); TextField("高", value: binding(\.windowHeight), format: .number)
            }
            HStack { Text("预览宽度"); TextField("宽度", value: binding(\.previewWidth), format: .number) }
            Button("重置上次位置") { model.updatePreferences { $0.windowX = 0.5; $0.windowY = 0.8 } }
            Text("上述几何设置用于浮动面板；刘海面板按屏幕适配。").font(.caption).foregroundStyle(.secondary)
            Divider()
            picker("固定内容位置", \.pinTo, [("top","顶部"),("bottom","底部")])
            integer("图片高度", \.imageMaxHeight, range: 1...200)
            toggle("自动打开预览", \.openPreviewAutomatically)
            integer("预览延迟（毫秒）", \.previewDelay, range: 200...100000).disabled(!model.preferences.openPreviewAutomatically)
            picker("匹配高亮", \.highlightMatch, [("bold","粗体"),("color","颜色"),("italic","斜体"),("underline","下划线")])
            toggle("显示特殊空白符号", \.showSpecialSymbols)
            toggle("显示剪贴板菜单栏图标", \.showInStatusBar)
            picker("图标", \.menuIcon, [("brand","NotchHub"),("clipboard","剪贴板"),("scissors","剪刀"),("paperclip","回形针")]).disabled(!model.preferences.showInStatusBar)
            toggle("菜单栏显示最近复制文本", \.showRecentCopyInMenuBar)
            toggle("显示搜索框", \.showSearch)
            picker("搜索框可见性", \.searchVisibility, [("always","始终"),("duringSearch","搜索期间")]).disabled(!model.preferences.showSearch)
            toggle("显示搜索框前标题", \.showTitle)
            toggle("显示来源应用图标", \.showApplicationIcons)
            toggle("显示十六进制颜色预览", \.showHexColorSwatch)
            toggle("显示页脚", \.showFooter)
            if !model.preferences.showFooter { Text("仍可使用 ⌘, 打开设置。").font(.caption) }
        }
    }
    private var pins: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("固定内容").font(.headline)
            if model.core.history.filter(\.isPinned).isEmpty { Text("在剪贴板历史中使用 ⌥P 固定内容。").foregroundStyle(.secondary) }
            ForEach(model.core.history.filter(\.isPinned)) { item in
                ClipboardPinEditor(model: model, item: item)
            }
        }
    }
    private var ignore: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用").font(.headline)
            toggle("只记录以下应用", \.ignoreAllAppsExceptListed)
            ForEach(model.preferences.ignoredApps, id: \.self) { bundle in
                HStack { Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle).flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleName") as? String } ?? bundle); Spacer(); Button("删除") { model.updatePreferences { $0.ignoredApps.removeAll { $0 == bundle } } } }
            }
            Button("添加应用…") {
                let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.canChooseDirectories = false
                if panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier { model.updatePreferences { if !$0.ignoredApps.contains(id) { $0.ignoredApps.append(id) } } }
            }
            Divider(); Text("粘贴板类型").font(.headline)
            ruleList(\.ignoredPasteboardTypes, regexp: false)
            Text("Concealed / Transient / AutoGenerated 类型始终排除。可添加 com.apple.is-remote-clipboard 忽略通用剪贴板。").font(.caption)
            Divider(); Text("正则表达式").font(.headline)
            ruleList(\.ignoreRegexp, regexp: true)
        }
    }
    private func ruleList(_ path: WritableKeyPath<ClipboardPreferences, [String]>, regexp: Bool) -> some View {
        ClipboardRuleEditor(values: Binding(get: { model.preferences[keyPath: path] }, set: { values in model.updatePreferences { $0[keyPath: path] = values } }), regexp: regexp)
    }
    private var advanced: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggle("暂停记录", \.ignoreEvents)
            Button("仅忽略下一次复制") { model.updatePreferences { $0.ignoreEvents = true; $0.ignoreOnlyNextEvent = true } }
            toggle("退出时清空普通历史", \.clearOnQuit)
            toggle("清空历史时清空系统剪贴板", \.clearSystemClipboard)
            toggle("清空时不再询问", \.suppressClearAlert)
            HStack { Text("轮询间隔（秒）"); TextField("间隔", value: binding(\.clipboardCheckInterval), format: .number).frame(width: 80) }
            Text("默认 0.5 秒；最小 0.05 秒。固定项不受退出清理影响。").font(.caption)
            Text("defaults write io.github.Wangxmian.NotchHub ignoreEvents -bool true").font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
            HStack { Button("清空普通历史") { model.clear() }; Button("清空全部") { model.clear(includingPinned: true) } }
        }
    }
}

struct ClipboardRuleEditor: View {
    @Binding var values: [String]
    let regexp: Bool
    @State private var draft = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack {
                    ClipboardRuleField(value: Binding(get: { values.indices.contains(index) ? values[index] : "" }, set: { new in
                        if values.indices.contains(index) { values[index] = new }
                    }), regexp: regexp)
                    Button("−") { if values.indices.contains(index) { values.remove(at: index) } }
                }
            }
            HStack { TextField(regexp ? "正则表达式" : "粘贴板类型", text: $draft)
                Button("添加") {
                    guard !draft.isEmpty else { return }
                    if regexp && (try? NSRegularExpression(pattern: draft)) == nil { error = "正则表达式无效"; return }
                    if !values.contains(draft) { values.append(draft) }; draft = ""; error = nil
                }
            }
            if let error { Text(error).foregroundStyle(.orange).font(.caption) }
        }
    }
}

private struct ClipboardRuleField: View {
    @Binding var value: String
    let regexp: Bool
    @State private var draft = ""
    @State private var error: String?
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading) {
            TextField("规则", text: $draft).focused($focused).onSubmit(commit)
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
        }.onAppear { draft = value }
        .onChange(of: focused) { if !$0 { commit() } }
        .onChange(of: value) { if !focused { draft = $0 } }
    }
    private func commit() {
        guard !regexp || (try? NSRegularExpression(pattern: draft)) != nil else { error = "正则表达式无效"; return }
        error = nil; if value != draft { value = draft }
    }
}

struct ClipboardPinEditor: View {
    @ObservedObject var model: ClipboardViewModel
    let item: ClipboardHistoryItem
    @State private var text = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("键", selection: Binding(get: { item.pinKey ?? "" }, set: { key in save { $0.pinKey = key } })) {
                    ForEach(Array(Set(model.core.availablePinCharacters).subtracting(model.core.history.filter { $0.id != item.id }.compactMap(\.pinKey)).union([item.pinKey ?? ""])).sorted(), id: \.self) { key in Text(key.isEmpty ? "无键" : key).tag(key) }
                }.frame(width: 90)
                TextField("别名", text: Binding(get: { item.alias ?? item.title }, set: { value in save { $0.alias = value } }))
                Button("删除") { model.delete(item.id) }
            }
            if [.plainText, .richText, .figmaText].contains(item.contentType) {
                TextField("内容", text: $text).onSubmit { do { try model.core.editText(item.id, text: text) } catch { self.error = error.localizedDescription } }
                Text(item.contentType == .plainText ? "回车保存内容" : "编辑后回车保存为纯文本，原格式将移除。").font(.caption).foregroundStyle(.secondary)
            } else { Text("此内容不是可编辑文本").font(.caption).foregroundStyle(.secondary) }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
        }.padding(8).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { text = (try? model.core.fullText(item)) ?? item.previewText }
    }
    private func save(_ change: (inout ClipboardHistoryItem) -> Void) { do { try model.core.mutateItem(item.id, change) } catch { self.error = error.localizedDescription } }
}

struct ClipboardShortcutRecorder: View {
    let title: String
    @Binding var value: KeyboardShortcutDescriptor?
    var global = false
    @State private var recording = false
    @State private var monitor: Any?
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title); Spacer()
                Button(recording ? "按下快捷键…" : label) {
                    guard !recording else { stop(); return }; recording = true
                    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                        MainActor.assumeIsolated {
                            if event.keyCode == 53 { stop(); return nil }
                            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                            guard let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty else { return nil }
                            let shortcut = KeyboardShortcutDescriptor(keyEquivalent: key, modifiers: ShortcutModifier.allCases.filter { flags.contains($0.eventFlags) })
                            if global && (shortcut.modifiers.isEmpty || !KeyboardShortcutCarbonMapper.canMap(shortcut) || (value != shortcut && !KeyboardShortcutConflictValidator.isAvailable(shortcut))) { error = "快捷键不可用或与系统冲突"; return nil }
                            value = shortcut; error = nil; stop(); return nil
                        }
                    }
                }
                Button("清除") { value = nil; stop() }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
        }.onDisappear(perform: stop)
    }
    private var label: String {
        guard let value else { return "未设置" }
        let glyph = value.modifiers.map { modifier in switch modifier { case .command: return "⌘"; case .option: return "⌥"; case .control: return "⌃"; case .shift: return "⇧" } }.joined()
        let key = value.keyEquivalent == " " ? "Space" : value.keyEquivalent == "\u{7f}" ? "Delete" : value.keyEquivalent.uppercased()
        return glyph + key
    }
    private func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; recording = false }
}
