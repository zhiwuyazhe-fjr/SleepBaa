# Profile 模块接口

## 1. Flutter 入口

- `ProfileFacade.saveProfile(...)`
- `ProfileFacade.saveNightMood(...)`
- `ProfileFacade.sendPhoneVerificationCode(...)`
- `ProfileFacade.bindPhoneNumber(...)`

## 2. 当前后端路由

### 2.1 `POST /api/app/bootstrap`

用途：

- 拉取用户资料、设置、画像快照

返回重点：

- `user.displayName`
- `user.tagline`
- `user.role`
- `user.dormId`
- `user.phoneNumber`
- `user.phoneLinkedAt`
- `settings.selectedNightMood`
- `userState`

### 2.2 `POST /api/profile/save`

用途：

- 保存资料和偏好设置

请求：

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
    "smartSuggestionsEnabled": true,
    "selectedNightMood": "calm"
  }
}
```

### 2.3 `POST /api/profile/night-mood`

用途：

- 保存夜间心情
- 触发今晚建议更新

请求：

```json
{
  "selectedNightMood": "calm",
  "source": "settings_save",
  "forceRefresh": true
}
```

### 2.4 `POST /api/auth/link-phone`

用途：

- 绑定手机号到当前资料

请求：

```json
{
  "phoneNumber": "13800138000",
  "verificationToken": "客户端验证码校验结果",
  "phoneAccessToken": "手机号会话 access token"
}
```

说明：

- 服务端真正校验依赖 `phoneAccessToken`
- 验证通过后才会写入用户资料

## 3. 读写集合

读：

- `users`
- `user_settings`
- `user_state`
- `card_snapshots`

写：

- `users`
- `user_settings`
- `user_state`
- `card_snapshots`
- `assistant_runs`

## 4. 当前数据约定

### `users`

核心字段：

- `displayName`
- `tagline`
- `role`
- `dormId`
- `phoneNumber`
- `phoneLinkedAt`

### `user_settings`

核心字段：

- `sleepGoalHours`
- `bedtimeReminderEnabled`
- `morningReminderEnabled`
- `dormAlertsEnabled`
- `smartSuggestionsEnabled`
- `selectedNightMood`

### `user_state`

核心字段：

- `latestNightMood`
- `tonightPlan`
- `profileSummary`
- `feedbackLoop`

## 5. 前端注意事项

- 页面不要直接依赖后端返回原始字段结构
- 一律通过 `ProfileFacade` 和 repository 更新
- 设置页已经去掉 Firebase 调试信息，不要再加回去
- 手机号绑定当前只做“绑定到资料”，不做账号升级
