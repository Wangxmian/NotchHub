NotchHub 1.3.0 开发分支（Apple Silicon / macOS 13+）
尚未通过完整 Maccy 2.7.1 功能一致验收，正式版仍为 1.2.0。

维护者：Wangxmian
项目主页：https://github.com/Wangxmian/NotchHub
问题反馈：https://github.com/Wangxmian/NotchHub/issues

使用：在顶部选择“番茄钟”。输入任务名称并回车；选择任务后开始专注。
右键任务可编辑、设置预计番茄数、完成或删除；拖动可排序。
专注记录保存任务名称、结束时间、时长及是否完整结束一轮。
完整结束才增加番茄数；提前停止保留时长。

本机从 EasyNotch 更名升级时保留原 NotchToolbox 数据目录和 AI 凭证服务标识，
这些仅用于本地数据兼容。应用公开身份、名称、图标和链接均属于 NotchHub。
原应用数据不会上传到 GitHub。

此构建使用临时签名、尚未 Apple 公证。未接入上游统计服务；开发分支使用 NotchHub 自有 GitHub 发布源检查更新。
本地 swiftc 编译不会提取 App Intents 元数据；系统快捷指令发现须使用完整 Xcode 构建验收。
原作者源码注释及第三方许可保留，来源说明见 README.md 和 THIRD_PARTY_NOTICES.md。

构建：python3 NotchToolbox/LocalBuild/build_local.py --output /absolute/path/NotchHub.app
验证：python3 NotchToolbox/LocalBuild/verify.py

剪贴板：Cmd+Shift+C 打开兼容浮动窗口；Cmd+, 打开统一剪贴板设置。
默认复制，Option 选择直接粘贴；完整动作取决于默认粘贴/去格式开关。
配置包含六类设置、36 个用户配置和四个快捷键。
剪贴板专项验证：python3 NotchToolbox/LocalBuild/verify.py ClipboardRegression.swift
完整工程验证：.github/workflows/clipboard-validation.yml（完整 Xcode 26.3）。
