# NotchHub 界面图片

这些 PNG 由应用自身的 SwiftUI 视图离屏渲染生成，并非系统桌面截图或设计稿。图片展示 `1.3.0-preview`，基于应用源码提交 `55ada81`。

| 图片 | 应用视图 | 内容 |
| --- | --- | --- |
| `pomodoro.png` | `PomodoroModuleView` | 示例待办、任务关联计时、番茄数和记录入口 |
| `clipboard.png` | `ClipboardBrowserView` | 示例文本、固定项、搜索和类型筛选 |
| `clipboard-settings.png` | `ClipboardPreferencesView` | 六类设置导航及通用配置 |

生成时使用临时本地存储、内存凭据存储和模拟剪贴板；退出后删除临时数据。未采集真实剪贴板或个人任务，未向 AI 服务发起请求。

图片仅说明界面布局，不构成全部 Maccy 行为、系统权限、多屏或发布验收已通过的证明。剪贴板能力的状态以仓库首页与开发分支说明为准。
