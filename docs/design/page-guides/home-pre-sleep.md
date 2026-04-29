# Home Pre Sleep Page Guide

最后核验日期：2026-04-29。代码入口：`lib/features/home/presentation/pages/home_pre_sleep_page.dart`。

## 路由

| Route | Page |
| --- | --- |
| `/home/pre_sleep` | `NightWelcomeGatePage`，若无需欢迎流则展示 `HomePreSleepPage`。 |

## 状态源

页面 `ListenableBuilder` 监听：

- `authRepository`
- `dormRepository`
- `notificationRepository`
- `recommendationRepository`
- `settingsRepository`
- `audioPlaybackController`
- `sleepCaptureRepository`
- `interferenceProbeController`

这些状态分别驱动问候语、宿舍摘要、通知未读数、今晚推荐、快捷入口、音频播放态、pending memo banner 和干扰因素卡片。

## 页面结构

当前主要结构：

1. 顶部问候与通知铃铛。
2. `HomeHeroPair`：左侧 `SleepRiskCard`，右侧 `StartSleepModeCard`。
3. 快捷功能入口：来自 `homeQuickActionDefinitionsFor(settings.homeQuickActionIds)`。
4. 干扰因素指标：噪声、光线、手机使用、情绪。
5. 今晚推荐：`recommendationRepository.tonightRecommendations.take(2)`，并追加睡前思绪清理快捷项。
6. pending memo banner：来自 `sleepCaptureRepository.pendingSleepMemoBanner`，支持展开和清除。

## 主要交互

| 交互 | 代码路径 |
| --- | --- |
| 点击开始睡眠 | `sleepExperienceController.enterSleepMode()`，成功后 `context.go(AppRoutes.homePostSleep)`。 |
| 编辑快捷入口 | `context.push(AppRoutes.homeQuickActionsEdit)`。 |
| 点击通知铃铛 | 进入 `/notifications`。 |
| 探测干扰因素 | `interferenceProbeController.detect(type)`；权限被拒时打开 App 设置。 |
| 点击推荐卡片 | `sleepExperienceController.handleRecommendationTap(...)`。 |
| 清除 pending banner | `sleepCaptureRepository.clearPendingBanner()`。 |

## UI 约束

- 顶部内容使用 `AppSpacing.xl` 横向 padding，底部保留约 108 的滚动留白。
- 首页核心卡片优先复用 `HomeHeroPair`、`SleepRiskCard`、`StartSleepModeCard`、`HomeActionCard`、`HomeMetricCard`。
- pending banner 是悬浮层，改布局时必须检查它和底部导航、助手 FAB 是否重叠。
- 快捷入口的配置来源是 `home_quick_actions.dart`，不要在页面里硬编码新增入口。

## 改动检查

- 改快捷入口：同步 `HomeQuickActionIds`、`kHomeQuickActionCatalog` 和设置默认值。
- 改干扰因素：同步 `InterferenceFactorType` 的 UI 文案、探测逻辑和分析页。
- 改推荐卡片：确认音频推荐的播放/暂停状态仍由 `AudioPlaybackController` 驱动。
- 改睡眠入口：确认 `/api/sleep/enter`、active session redirect 和睡眠模式通知仍能闭环。
