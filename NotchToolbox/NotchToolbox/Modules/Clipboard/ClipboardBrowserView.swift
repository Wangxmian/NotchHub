import AppKit
import SwiftUI

struct ClipboardBrowserView: View {
    @ObservedObject var model: ClipboardViewModel
    var close: (() -> Void)?
    var floating = false
    @FocusState private var focused: Bool
    @State private var monitor: Any?
    @State private var presentationID = UUID()
    @State private var previewDragStart: CGFloat?

    var body: some View {
        VStack(spacing: 8) {
            header
            HStack(alignment: .top, spacing: 8) {
                if floating && model.previewOnLeft { detail }
                history
                if !floating || !model.previewOnLeft { detail }
            }
            if let error = model.lastPasteError {
                Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
            }
            if model.preferences.showFooter { footer }
        }
        .padding(12)
        .background(Color.black.opacity(0.9))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            model.presentationIsFloating = floating
            model.activePresentationID = presentationID
            model.captureTarget(); model.refresh(); model.isPresented = true; model.isInputFocused = true
            model.closePresentation = close
            model.schedulePreview()
            DispatchQueue.main.async { focused = true }

        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
            if model.activePresentationID == presentationID { model.activePresentationID = nil; model.isPresented = false; model.isInputFocused = false }
        }
        .onChange(of: focused) { if model.activePresentationID == presentationID { model.isInputFocused = $0 } }
        .onChange(of: model.focusRequest) { _ in
            guard model.isPresented, model.presentationIsFloating == floating else { return }
            model.activePresentationID = presentationID
            focused = false; DispatchQueue.main.async { focused = true }
        }
    }
    @ViewBuilder private var detail: some View {
        if model.previewVisible, let item = model.selectedItem {
            if floating && !model.previewOnLeft { previewDivider }
            ClipboardDetailView(core: model.core, item: item)
                .frame(width: floating ? max(1, model.presentedPreviewWidth - 12) : 220)
            if floating && model.previewOnLeft { previewDivider }
        }
    }
    private var previewDivider: some View {
        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 4)
            .contentShape(Rectangle()).help("拖动调整预览宽度")
            .gesture(DragGesture().onChanged { value in
                if previewDragStart == nil { previewDragStart = model.preferences.previewWidth }
                let delta = model.previewOnLeft ? value.translation.width : -value.translation.width
                model.updatePreferences { $0.previewWidth = (previewDragStart ?? 400) + delta }
            }.onEnded { _ in previewDragStart = nil })
    }
    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                if model.preferences.showTitle { Text("NotchHub").font(.headline) }
                TextField("搜索剪贴板…", text: $model.query).textFieldStyle(.plain).focused($focused)
                    .opacity(model.preferences.showSearch && (model.preferences.searchVisibility == "always" || !model.query.isEmpty) ? 1 : 0)
                    .accessibilityLabel("搜索剪贴板")
                Spacer(minLength: 0)
                Button { model.updatePreferences { $0.ignoreEvents.toggle(); $0.ignoreOnlyNextEvent = false } } label: {
                    Image(systemName: model.preferences.ignoreEvents ? "play.fill" : "pause.fill")
                }.help(model.preferences.ignoreEvents ? "恢复记录" : "暂停记录")
                Button { model.showSettings() } label: { Image(systemName: "gearshape") }
            }
            if !floating {
                Picker("类型", selection: $model.filter) {
                    Text("全部").tag("all"); Text("文本").tag("text"); Text("图片").tag("image"); Text("文件").tag("file"); Text("固定").tag("pinned")
                }.pickerStyle(.segmented)
            }
        }
    }
    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if model.results.isEmpty {
                        Text(model.query.isEmpty ? "还没有剪贴板历史" : "没有匹配的历史").font(.caption).foregroundStyle(.secondary).padding()
                    }
                    ForEach(model.results) { result in
                        row(result).id(result.id)
                    }
                }
            }
            .onChange(of: model.selectedID) { id in if let id { proxy.scrollTo(id) } }
        }
        .frame(minWidth: 160, maxWidth: .infinity, maxHeight: .infinity)
    }
    private func row(_ result: ClipboardSearchService.Result) -> some View {
        let item = result.item
        return Button { model.perform(item.id, close: close) } label: {
            HStack(alignment: .center, spacing: 7) {
                if model.preferences.showApplicationIcons, let bundle = item.sourceAppBundleID,
                   let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 16, height: 16)
                }
                if item.isPinned { Image(systemName: "pin.fill").font(.caption) }
                if let url = model.core.thumbnailURL(item) {
                    CachedThumbnailImage(url: url) { Image(systemName: "photo") }
                        .frame(maxWidth: 100, maxHeight: CGFloat(model.preferences.imageMaxHeight))
                } else {
                    if model.preferences.showHexColorSwatch, let color = hexColor(item.title) {
                        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 16, height: 16)
                    }
                    Text(highlighted(result)).font(.system(size: 12)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                Text(shortcut(item)).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background(model.selectedID == item.id ? Color.white.opacity(0.16) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in if hovering { model.selectedID = item.id; model.schedulePreview() } }
        .contextMenu {
            Button(item.isPinned ? "取消固定" : "固定") { model.pin(item.id) }
            Button("复制") { model.perform(item.id, action: .copy, close: close) }
            Button("粘贴") { model.perform(item.id, action: .paste, close: close) }
            Button("纯文本粘贴") { model.perform(item.id, action: .pastePlainText, close: close) }
            Button("删除", role: .destructive) { model.delete(item.id) }
        }
        .accessibilityLabel(item.title)
        .accessibilityValue(model.selectedID == item.id ? "已选中" : "未选中")
        .accessibilityHint("选择后执行默认复制或粘贴动作")
        .accessibilityAction(named: Text(item.isPinned ? "取消固定" : "固定")) { model.pin(item.id) }
        .accessibilityAction(named: Text("删除")) { model.delete(item.id) }
    }
    private func shortcut(_ item: ClipboardHistoryItem) -> String {
        let prefix = NSEvent.modifierFlags.contains(.option) ? "⌥" : "⌘"
        if let key = item.pinKey { return prefix + key.uppercased() }
        let ordinary = model.results.filter { !$0.item.isPinned }
        if let index = ordinary.firstIndex(where: { $0.id == item.id }), index < 9 { return prefix + String(index+1) }
        return ""
    }
    private func highlighted(_ result: ClipboardSearchService.Result) -> AttributedString {
        let raw = result.text
        var value = AttributedString(raw)
        for range in result.ranges {
            guard let lo = AttributedString.Index(range.lowerBound, within: value), let hi = AttributedString.Index(range.upperBound, within: value) else { continue }
            switch model.preferences.highlightMatch {
            case "color": value[lo..<hi].foregroundColor = .yellow
            case "italic": value[lo..<hi].font = .system(size: 12).italic()
            case "underline": value[lo..<hi].underlineStyle = .single
            default: value[lo..<hi].font = .system(size: 12, weight: .bold)
            }
        }
        return value
    }
    private func hexColor(_ text: String) -> Color? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#"), [4, 7].contains(trimmed.count) else { return nil }
        var hex = String(trimmed.dropFirst())
        if hex.count == 3 { hex = hex.map { String(repeating: String($0), count: 2) }.joined() }
        guard let value = UInt32(hex, radix: 16) else { return nil }
        return Color(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255)
    }
    private var footer: some View {
        HStack(spacing: 12) {
            ForEach(Array(["清空", "设置", "关于", "退出"].enumerated()), id: \.offset) { index, title in
                Button(index == 0 && NSEvent.modifierFlags.contains(.shift) ? "清空全部" : title) { model.activateFooter(index) }
                    .padding(4).background(model.selectedFooter == index ? Color.white.opacity(0.16) : .clear)
                    .onHover { if $0 { model.selectedID = nil; model.selectedFooter = index } }
            }
            Spacer()
            Button { model.previewVisible.toggle() } label: { Image(systemName: "sidebar.right") }.help("显示预览 Control+Space")
        }.font(.caption).buttonStyle(.borderless)
    }
}

struct ClipboardDetailView: View {
    let core: ClipboardCore
    let item: ClipboardHistoryItem
    @State private var text = ""
    @State private var image: NSImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image { Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: .infinity) }
            else { ClipboardTextPreview(text: text).frame(maxHeight: .infinity) }
            Divider()
            Text(item.sourceAppName ?? "未知来源")
            Text("首次：\((item.firstCopiedAt ?? item.copiedAt).formatted())")
            Text("最近：\(item.copiedAt.formatted())")
            Text("复制次数：\(item.copyCount)")
            if let image { Text("尺寸：\(Int(image.size.width)) × \(Int(image.size.height))") }
        }.font(.system(size: 10)).foregroundStyle(.secondary)
        .task(id: item.contentHash) { text = (try? core.fullText(item)) ?? item.previewText; image = (try? core.imageData(item)).flatMap(NSImage.init(data:)) }
    }
}

private struct ClipboardTextPreview: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let view = NSTextView(); view.isEditable = false; view.isSelectable = true; view.drawsBackground = false
        view.font = .systemFont(ofSize: 12); view.textColor = .white
        view.isHorizontallyResizable = false; view.isVerticallyResizable = true
        view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.minSize = .zero; view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.string = text; scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        if let view = scroll.documentView as? NSTextView, view.string != text { view.string = text }
    }
}
