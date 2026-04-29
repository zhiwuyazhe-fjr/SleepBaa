# State and Data Flow

最后核验日期：2026-04-29。本文以 `AppScope`、repository interface、facade、页面 `ListenableBuilder` 为准。

## 总体流向

```text
Page
  -> context.appServices
  -> Facade / Controller / Repository
  -> InMemory repository or CloudBase repository
  -> CloudBaseAppApiClient
  -> app-api
  -> bootstrap/reconcile updates local snapshot
  -> ChangeNotifier/Listenable notifies UI
```

页面层不直接访问 CloudBase 集合。需要写数据时，优先找已有 facade 或 repository 方法；需要跨页面副作用时，放在 controller。

## 状态来源

| 状态类型 | 主要来源 | UI 更新方式 |
| --- | --- | --- |
| 用户与设置 | `AuthRepository`、`UserSettingsRepository`、`ProfileFacade` | repository/facade `ChangeNotifier`。 |
| 睡眠会话 | `SleepSessionRepository`、`SleepExperienceController`、`SleepFacade` | 会话 repository 与睡眠 controller 通知。 |
| 推荐和音频 | `RecommendationRepository`、`AudioPlaybackController` | 首页和睡眠页监听。 |
| 事记/梦记 | `SleepCaptureRepository`、`DreamRepository`、`DreamFacade` | 列表页监听对应 repository。 |
| 宿舍 | `DormRepository`、`DormFacade`、宿舍在线/位置 controller | 宿舍页监听 repository/controller。 |
| 通知 | `NotificationRepository`、`NotificationFacade`、通知 sync controller | 通知中心和首页未读数监听 repository。 |
| 助手 | `AssistantRepository`、`AssistantConversationController`、`AssistantFacade` | 助手页监听 controller/repository。 |
| 洞察/报告 | `InsightsRepository`、`InsightsFacade` | 我的页报告和分析页监听。 |

## Bootstrap and Refresh

CloudBase 模式启动后：

1. `AuthRepository.ensureAuthenticated()` 确保 session。
2. `CloudBaseAppApiClient.bootstrap()` 请求 `/api/app/bootstrap`。
3. `CloudBaseBootstrapSnapshot` 解析 payload。
4. 各 CloudBase repository 写入本地快照并 `notifyListeners()`。
5. `AppScope._bootstrapExperience()` 启动通知、宿舍在线、睡眠体验等控制器。

App resume 时，`AppScope` 会重新确保认证，并在通过身份验证后同步睡眠、通知和宿舍状态。

## 首页监听面

`HomePreSleepPage` 当前监听：

- `authRepository`
- `dormRepository`
- `notificationRepository`
- `recommendationRepository`
- `settingsRepository`
- `audioPlaybackController`
- `sleepCaptureRepository`
- `interferenceProbeController`

所以首页 UI 改动通常只需要在页面和 `home` 私有组件内完成；若数据不对，再分别查这些状态源。

## 夜间欢迎

`NightWelcomeGatePage` 监听：

- `settingsRepository`
- `nightWelcomeController`

它会根据 `NightWelcomeController.shouldShowWelcome(...)` 决定展示 `NightMoodWelcomeFlow`，或直接进入 `HomePreSleepPage`。完成/跳过欢迎后，会写本地 `EveningWelcomeLocalStore`，再通过 `ProfileFacade` 保存夜间情绪或鼓励语，使 CloudBase bootstrap 刷新后仍保留。

## 梦记页

`DreamJournalPage` 使用 `sleepCaptureRepository.recordsByType(SleepCaptureType.dream)` 合并助手 capture 记录和内置 `DreamContent.entries`。因此：

- 助手 capture 成功后，梦记页会通过 `SleepCaptureRepository` 刷新。
- 静态内容来自 `lib/features/dream/presentation/dream_content.dart`。
- 进入详情页的 record 型事记使用 `state.extra`，不要改成 query string。

## 通知流

通知分两层：

- 系统/本地通知：`AppNotificationService`，负责睡眠模式通知和就寝提醒。
- App 内通知与 toast：`UnifiedNotificationDispatcher` + `PassiveToastNotificationChannel`。

通知中心数据来自 `NotificationRepository`。CloudBase 模式下 `markRead` 会调用 `/api/notifications/read`。

## 助手流

助手页提交消息后：

1. `AssistantConversationController` 创建本地 pending message。
2. `AssistantReplyGateway` 调流式接口。
3. 每个 `message_delta` 更新正在展示的 assistant message。
4. `message_completed` 写入完成态。
5. `done.backgroundSyncPending` 触发后续 reconcile。
6. capture 流额外处理 `capture_record` 和 `surface_patch`。

## UI 排查顺序

| 问题 | 优先检查 |
| --- | --- |
| 页面文字或布局不对 | 页面文件和私有 widget。 |
| 点击后 UI 没刷新 | 页面监听的 `Listenable` 是否覆盖对应 repository/controller。 |
| CloudBase 后数据回滚 | serializer 默认值、bootstrap payload、repository 本地快照。 |
| 本地模式正常但 CloudBase 异常 | `CloudBase*Repository` 对应方法和 `app-api` 响应。 |
| 助手显示不连续 | SSE event 解析、turn busy、controller pending message 状态。 |

## 新功能落点

- 只影响单页视觉：改 `features/<feature>/presentation/pages` 或私有 `widgets`。
- 多页复用 UI：新增到 `lib/core/widgets`。
- 新业务动作：优先扩展 facade；需要持久化再扩 repository interface。
- 需要后端写入：先扩 `app-api`，再补 CloudBase repository 和 serializer。
