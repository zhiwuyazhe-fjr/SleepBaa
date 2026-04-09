# 通知系统 API 文档

## 1. 设计目标
- 统一业务侧调用入口，避免各页面直接调用 `showSnackBar`
- 解耦“业务触发”与“显示实现”
- 支持通道扩展：底部提示、顶部提示、中部提示、系统通知

## 2. 架构分层
- 业务层：调用统一 API 发送通知请求
- 分发层：根据 `kind + channel` 路由到匹配通道
- 通道层：负责具体渲染（当前为 `PassiveToast`）

## 3. 核心类型

### 3.1 传输与通道枚举
- `NotificationDeliveryKind`
  - `inApp`：应用内显示
  - `system`：系统通知（Android/iOS 预留）
- `InAppNotificationChannelType`
  - `passiveToast`
  - `topBanner`（预留）
  - `centerOverlay`（预留）

### 3.2 请求模型
- `UnifiedNotificationRequest`
  - `kind`：投递类型
  - `channel`：通道标识
  - `payload.message`：通知文案
  - `payload.metadata`：扩展参数（上下文、key 等）
  - `duration`：显示时长

### 3.3 统一接口
- `UnifiedNotificationApi.notify(UnifiedNotificationRequest request)`
- 默认实现：`UnifiedNotificationDispatcher`

## 4. 当前已接入通道

### 4.1 Passive Toast 通道
- 入口函数：`notifyPassiveToast(context, message: ..., duration: ..., toastKey: ...)`
- 通道实现：`PassiveToastNotificationChannel`
- 渲染实现：`PassiveToastController`

### 4.2 行为约定
- 支持高频触发队列
- 入场动画期间禁止点按关闭
- 入场完成后可点按关闭
- 显示态收到新消息时，允许快速切换至下一条

## 5. 业务侧调用示例

```dart
notifyPassiveToast(
  context,
  message: '宿舍规则已保存到当前会话。',
);
```

```dart
await context.appServices.notificationApi.notify(
  UnifiedNotificationRequest(
    kind: NotificationDeliveryKind.inApp,
    channel: InAppNotificationChannelType.passiveToast.name,
    payload: const UnifiedNotificationPayload(message: '已记录晨间反馈'),
  ),
);
```

## 6. 扩展指南（新增通道）
1. 继承 `InAppNotificationChannelProtocol` 或 `SystemNotificationChannelProtocol`
2. 实现 `channel` 与 `deliver(request)`
3. 在 `AppScope` 初始化时注册到 `UnifiedNotificationDispatcher`
4. 业务侧保持统一 API 调用，不改页面逻辑

## 7. 已迁移页面
- `dorm_page.dart`
- `dorm_rules_page.dart`
- `morning_feedback_page.dart`
- `night_awakening_log_page.dart`
- `settings_page.dart`
- `avatar_picker.dart`

## 8. 协作约定
- 新增业务提示时，禁止直接 `showSnackBar`
- 优先使用 `notifyPassiveToast` 或统一 `notify` 接口
- 若需新样式（顶部/中部），新增通道，不改业务触发点
