# NotchHub 高清界面展示

这些图片展示 `1.3.0-preview`，基于应用源码提交 `15fe585`，使用真实 SwiftUI 组件和原生 Retina backing scale 2 导出为无损 PNG，没有对旧图插值放大。

| 图片 | 像素尺寸 | 展示内容 |
| --- | --- | --- |
| `notch-collapsed@2x.png` | 2000 × 360 | 任务与剩余时间显示在刘海两侧 |
| `notch-pomodoro@2x.png` | 2000 × 940 | 刘海展开后的待办与专注计时 |
| `notch-music@2x.png` | 2000 × 740 | 刘海展开后的歌曲、进度与控制 |
| `notch-clipboard@2x.png` | 2000 × 940 | 刘海展开后的历史、搜索与固定项 |
| `clipboard-settings@2x.png` | 1520 × 960 | 独立设置内容区 |

桌面背景、菜单栏、屏幕边缘和摄像头位置为文档示意，不是系统桌面截图。面板使用现有 `PanelHeaderView`、`PanelShellPresentation` 尺寸、`MorphingExpandedNotchShape` 与 `NotchShellPathBuilder` 曲线和阴影参数，并嵌入应用真实功能视图；收起状态使用 `PomodoroRestVariantContentView`。

生成时使用临时本地存储、内存凭据、模拟剪贴板与示例音乐信息；退出后删除临时数据。未采集真实剪贴板、个人任务或密钥，也未向 AI 服务发起请求。图片不构成系统权限、多屏或全部 Maccy 功能验收已通过的证明。
