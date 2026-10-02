# NotchHub

将音乐、待办专注、剪贴板和 AI 对话放进 Mac 顶部刘海区。

维护者：[Wangxmian](https://github.com/Wangxmian)。

![NotchHub](assets/NotchHubLogo.png)

## 下载

前往 [Releases](https://github.com/Wangxmian/NotchHub/releases) 下载最新 DMG。
当前本地打包版本支持 Apple Silicon，要求 macOS 13 或更新版本。
应用使用本地临时签名，尚未经过 Apple 公证。

## 功能

- **音乐**：查看当前歌曲，控制播放、暂停与切歌。
- **番茄钟 + 待办**：添加、编辑、完成、删除与排序任务；选择任务开始计时。
- **专注记录**：完整结束一轮才增加番茄数，提前结束保留专注时长。
- **刘海摘要**：收起时显示当前任务和剩余时间。
- **剪贴板**：保存并浏览复制历史。
- **AI Chat**：配置自己的 API Key，进行流式对话和管理会话。

顶部默认入口为“音乐 / 番茄钟 / 更多”。文件暂存入口和拖入唤起已移除。
没有接入原作者的统计服务，也不会从原作者的更新源自动下载版本。

## 剪贴板开发分支

`clipboard-maccy-parity` 正在对齐用户提供的 Maccy 2.7.1。包含六类统一设置、四种搜索、OCR、固定内容编辑、复制/粘贴动作、浮动面板、脚本控制及 App Intents。
这些功能正在验收，尚未发布为完整功能一致版本；正式 Releases 保持原有稳定版本。
完整 Xcode 构建、原有模块测试和隔离行为回归由 GitHub Actions 执行。发布前仍需实测 Figma、中文输入法、多屏、直接粘贴授权、系统快捷指令和更新安装。

## 构建与验证

使用完整 Xcode 打开 `NotchToolbox/NotchToolbox.xcodeproj`，选择 `NotchToolbox` scheme。
项目内部模块名保留为 NotchToolbox，应用产品名为 NotchHub。

仅安装 Command Line Tools 时，可使用本地构建脚本：

```sh
python3 NotchToolbox/LocalBuild/build_local.py --template /Applications/NotchHub.app --output /absolute/path/NotchHub.app
python3 NotchToolbox/LocalBuild/verify.py
python3 NotchToolbox/LocalBuild/verify.py ClipboardRegression.swift
```

脚本复用模板应用已编译的资源目录与音乐辅助工具。首次构建可将模板指向已有的 EasyNotch 应用。

## 反馈

请前往 [Issues](https://github.com/Wangxmian/NotchHub/issues) 提交问题或建议。

## 来源与署名

NotchHub 基于 [designerluojie/EasyNotch](https://github.com/designerluojie/EasyNotch) 的源码改造。
感谢原作者洛杰；原有代码作者注释和第三方许可声明保留。
本项目新增待办与番茄钟关联、专注记录、导航调整及 NotchHub 品牌信息。
收到的上游源码未包含顶层 LICENSE，本项目不为上游代码擅自添加新的许可证。
音乐辅助工具的许可证见 `NotchToolbox/Vendor/nowplaying-cli.LICENSE`。
