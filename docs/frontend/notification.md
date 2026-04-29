# Notification

最后核验日期：2026-04-29。本文以 `lib/core/notifications/**`、`lib/core/widgets/passive_toast.dart` 与 `NotificationRepository` 为准。

## 文件地图

| 文件 | 职责 |
| --- | --- |
| `lib/core/notifications/unified_notification.dart` | 统一通知 payload、request、channel 协议和 dispatcher。 |
| `lib/core/notifications/passive_toast_notification.dart` | App 内被动 toast channel。 |
| `lib/core/widgets/passive_toast.dart` | toast 队列、展示与关闭动画。 |
| `lib/core/notifications/app_notification_service.dart` | 系统本地通知、睡眠模式通知、就寝提醒。 |
| `lib/core/notifications/bedtime_reminder_sync_controller.dart` | 根据设置同步就寝提醒。 |
| `lib/core/notifications/sleep_mode_notification_controller.dart` | 根据 active sleep session 显示/取消睡眠模式通知。 |
| `lib/core/notifications/cloudbase_notification_sync_controller.dart` | CloudBase 模式通知快照同步。 |
| `lib/core/notifications/notification_navigation_coordinator.dart` | 通知点击后的跳转和已读。 |
| `lib/features/notifications/presentation/pages/notifications_page.dart` | 通知中心页面。 |

## 统一通知通道

`UnifiedNotificationDispatcher` 实现 `UnifiedNotificationApi`，可注册多个 channel。当前 `AppScope` 注册了 `PassiveToastNotificationChannel`，用于 App 内非阻塞提示。

发送 App 内 toast 优先使用：

```dart
await notifyPassiveToast(context, message: '提示文案');
```

不要在页面里直接操作 `PassiveToastController`，除非你正在扩展通知基础设施。

## 通知中心数据

通知列表来自 `NotificationRepository`：

- `items`
- `unreadNotifications()`
- `markRead(notificationId)`
- `upsertNotification(notification)`

CloudBase 实现中，`markRead` 会调用 `/api/notifications/read`；in-memory 实现则只更新本地状态。

## 系统通知

`AppNotificationService` 负责：

- 初始化本地通知能力。
- 展示/取消睡眠模式常驻通知。
- 安排/取消就寝提醒。
- 处理通知启动 intent。

系统通知只应由 controller/service 触发，不要在页面点击事件中直接调用插件。

## 同步控制器

| Controller | 触发时机 | 职责 |
| --- | --- | --- |
| `BedtimeReminderSyncController` | 设置变化和 AppScope bootstrap 后 | 根据设置安排或取消 bedtime reminder。 |
| `SleepModeNotificationController` | 睡眠会话变化 | active session 存在时展示睡眠模式通知，否则取消。 |
| `CloudBaseNotificationSyncController` | CloudBase 模式启动与恢复 | 同步远端通知快照。 |

## 页面使用规则

- 首页未读数读取 `notificationRepository.unreadNotifications().length`。
- 通知中心点击条目后调用 `markRead`，再根据通知类型跳转。
- 被动 toast 用于轻量结果提示，不应承载必须确认的危险操作。
- 需要用户确认的场景使用 `lib/core/widgets/modals/**`。

## 新增通知类型检查

1. 在模型里确认 `NotificationItem` 是否已有足够字段。
2. 在 repository 写入处补 `upsertNotification`。
3. 如果要进入通知中心，保证 bootstrap payload 包含该通知。
4. 如果要系统提醒，走 `AppNotificationService` 或新增 controller。
5. 如果要点击跳转，更新 `NotificationNavigationCoordinator` 和路由 helper。
