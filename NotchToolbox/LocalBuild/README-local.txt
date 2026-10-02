NotchHub 1.2.0（Apple Silicon / macOS 13+）

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

此构建使用临时签名、尚未 Apple 公证。未接入上游统计或自动更新服务。
原作者源码注释及第三方许可保留，来源说明见 README.md 和 THIRD_PARTY_NOTICES.md。

构建：python3 NotchToolbox/LocalBuild/build_local.py --output /absolute/path/NotchHub.app
验证：python3 NotchToolbox/LocalBuild/verify.py
