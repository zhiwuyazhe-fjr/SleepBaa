# Profile 模块接口

## Flutter 入口

- `ProfileFacade.saveProfile(...)`
- `ProfileFacade.saveNightMood(...)`
- `ProfileFacade.sendPhoneVerificationCode(...)`
- `ProfileFacade.authenticateWithPhone(...)`
- `ProfileFacade.signOut()`

## 后端路由

### `POST /api/app/bootstrap`

用途：

- 拉取用户资料、设置、睡眠记录、通知、宿舍信息和卡片快照。

当前重点返回字段：

- `user.displayName`
- `user.tagline`
- `user.role`
- `user.dormId`
- `user.phoneNumber`
- `user.phoneLinkedAt`
- `settings.sleepGoalHours`
- `settings.bedtimeReminderEnabled`
- `settings.bedtimeReminder`
- `settings.selectedNightMood`
- `sleepSessions[].sleepGoalMet`
- `userState`

说明：

- `sleepSessions[].sleepGoalMet` 为后端派生字段，不直接持久化到 `sleep_sessions` 文档。
- 派生规则基于当前 `settings.sleepGoalHours`，仅对已结束且时长稳定的睡眠记录返回 `true` / `false`；其余记录返回 `null`。

### `POST /api/profile/save`

用途：

- 保存资料和偏好设置。

请求示例：

```json
{
  "profile": {
    "displayName": "小林",
    "tagline": "今晚想早点稳下来",
    "role": "宿舍睡眠记录发起人"
  },
  "settings": {
    "sleepGoalHours": 7.5,
    "bedtimeReminderEnabled": true,
    "morningReminderEnabled": true,
    "dormAlertsEnabled": true,
    "bedtimeReminder": { "hour": 23, "minute": 10 },
    "smartSuggestionsEnabled": true,
    "selectedNightMood": "calm"
  }
}
```

### `POST /api/profile/night-mood`

用途：

- 保存夜间心情。
- 触发今晚建议刷新。

请求示例：

```json
{
  "selectedNightMood": "calm",
  "source": "settings_save",
  "forceRefresh": true
}
```

## 读写集合

读取：

- `users`
- `user_settings`
- `user_state`
- `card_snapshots`

写入：

- `users`
- `user_settings`
- `user_state`
- `card_snapshots`
- `assistant_runs`

## 数据约定

### `user_settings`

核心字段：

- `sleepGoalHours`
- `bedtimeReminderEnabled`
- `morningReminderEnabled`
- `dormAlertsEnabled`
- `bedtimeReminder`
- `smartSuggestionsEnabled`
- `selectedNightMood`

### `sleep_sessions`

持久化核心字段：

- `startedAt`
- `endedAt`
- `sleepDayKey`
- `status`
- `sleepModeActive`
- `trackedDurationMinutes`
- `segments`
- `summary`

bootstrap / 上下文派生字段：

- `sleepGoalMet`

## 前端注意事项

- 页面不要直接依赖后端原始字段结构之外的隐式语义。
- 统一通过 `ProfileFacade` 和 repository 更新资料与设置。
- 睡前提醒是本地定时通知链路，依赖 `user_settings.bedtimeReminder*` 字段。
