# Frontend Overview

最后核验日期：2026-04-29。本文以 `lib/app/routes.dart`、`lib/core/app_scope.dart`、`lib/core/data/repositories.dart`、`lib/core/facades/app_facades.dart` 和 `lib/features/**/presentation/**` 为准。

## 入口结构

```text
lib/main.dart
  -> SleepDormApp
  -> AppScope
  -> MaterialApp.router
  -> GoRouter
  -> features/**/presentation/pages
```

`AppScope` 是应用服务装配中心。页面通常通过 `context.appServices` 取得 repository、controller 或 facade。

## 目录职责

| 目录 | 职责 |
| --- | --- |
| `lib/app` | App 入口、路由、主题 token。 |
| `lib/core/backend` | CloudBase 环境、认证、session、HTTP client、助手 SSE gateway。 |
| `lib/core/data` | Repository interface、in-memory 实现、CloudBase 实现、model serializer。 |
| `lib/core/facades` | 面向页面的业务 facade，聚合 repository/controller。 |
| `lib/core/models` | Flutter 领域模型。 |
| `lib/core/notifications` | 本地通知、被动 toast、提醒同步、通知跳转协调。 |
| `lib/core/state` | 跨页面 controller，例如睡眠体验、夜间欢迎、宿舍在线等。 |
| `lib/core/widgets` | 共享 UI 组件。 |
| `lib/features/**/presentation` | 功能页面、私有组件和页面 controller。 |

## AppScope 装配

`lib/core/app_scope.dart` 会根据 `AppEnvironment.usesCloudBase` 装配两套数据层：

| 模式 | Repository 实现 |
| --- | --- |
| in-memory | `InMemory*Repository`，用于本地 UI 和测试。 |
| CloudBase | `CloudBase*Repository`，通过 `CloudBaseAppApiClient` 调 `app-api`。 |

当前 repository interface：

- `AuthRepository`
- `UserSettingsRepository`
- `RecommendationRepository`
- `SleepSessionRepository`
- `FeedbackRepository`
- `SleepCaptureRepository`
- `NotificationRepository`
- `DormRepository`
- `DreamRepository`
- `InsightsRepository`
- `AssistantRepository`
- `PushNotificationGateway`

## Controller

`AppScope` 中创建的跨页面 controller：

| Controller | 作用 |
| --- | --- |
| `AudioPlaybackController` | 音频播放状态。 |
| `DormPresenceSyncController` | 宿舍位置/返回状态同步。 |
| `DormOnlineSyncController` | App 在线心跳。 |
| `DormLiveStatusController` | 宿舍 live 状态作用域。 |
| `DormNoiseSampleLedger` | 宿舍噪声采样账本。 |
| `InterferenceProbeController` | 睡前干扰因素探测状态。 |
| `SleepExperienceController` | 睡眠模式、晨间反馈、睡眠通知联动。 |
| `NightWelcomeController` | 夜间欢迎流程是否展示。 |
| `AssistantConversationController` | 助手对话和 capture 流程。 |
| `BedtimeReminderSyncController` | 就寝提醒与系统通知同步。 |
| `CloudBaseNotificationSyncController` | CloudBase 通知快照同步。 |
| `SleepModeNotificationController` | 睡眠模式常驻通知。 |

## Facade

页面优先使用 facade 表达业务动作：

| Facade | 聚合对象 |
| --- | --- |
| `ProfileFacade` | 用户资料、设置、账号偏好。 |
| `SleepFacade` | 睡眠会话、推荐、音频控制。 |
| `DormFacade` | 宿舍、成员、规则、邀请。 |
| `NotificationFacade` | 通知列表与已读。 |
| `DreamFacade` | 梦记列表与保存。 |
| `InsightsFacade` | 分析/报告快照。 |
| `AssistantFacade` | 助手线程、消息、profile。 |

## 路由壳层

`lib/app/routes.dart` 使用 `StatefulShellRoute.indexedStack` 构建三个底部 Tab：

| Tab | Route | Page |
| --- | --- | --- |
| 首页 | `/home/pre_sleep` | `NightWelcomeGatePage`，必要时进入 `HomePreSleepPage`。 |
| 宿舍 | `/dorm` | `DormPage`。 |
| 我的 | `/profile` | `ProfilePage`。 |

`/home` 会根据 `HomeMode` 重定向到 `/home/pre_sleep` 或 `/home/post_sleep`。根路径 `/` 重定向到 `/home`。

## CloudBase 登录门禁

CloudBase 模式下，路由层会先确保认证与手机号验证：

- 正在认证时展示 gate/loading。
- 未完成手机号身份验证时进入 `/auth/phone`。
- 验证完成后放行目标页面。
- 如果存在 active sleep session，根路径、`/home`、`/home/pre_sleep` 会重定向到 `/home/post_sleep`。

## 页面开发规则

- 页面读状态优先使用 `context.appServices` 中已有 facade/controller/repository。
- 跨功能共享 UI 放 `lib/core/widgets/**`；功能私有 UI 放对应 `features/<feature>/presentation/widgets/**`。
- 新增页面必须同步更新 `lib/app/routes.dart`、[page-map.md](page-map.md) 和必要的设计说明。
- CloudBase 写入语义不要写在页面里，放到 repository/facade/controller。
