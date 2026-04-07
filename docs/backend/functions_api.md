# Functions / API 契约

## 1. 说明

Flutter 客户端当前不直接写 CloudBase 业务集合，只调用 `app-api`。

本文件只记录当前 MVP 必须接好的接口和触发器。

## 2. HTTP Function

函数名：`app-api`

客户端只调用以下路由。

### 2.1 `POST /api/app/bootstrap`

用途：

- 启动后拉取当前用户聚合快照

返回核心字段：

- `user`
- `settings`
- `dorm`
- `sleepSessions`
- `dreamEntries`
- `assistantThreads`
- `assistantMessages`
- `cardSnapshots`
- `userState`

### 2.2 `POST /api/profile/save`

用途：

- 保存用户资料
- 保存用户设置

请求：

```json
{
  "profile": {},
  "settings": {}
}
```

### 2.3 `POST /api/profile/night-mood`

用途：

- 保存夜间心情
- 生成今晚建议

请求：

```json
{
  "selectedNightMood": "calm",
  "source": "settings_save",
  "forceRefresh": true
}
```

返回重点：

- `dateKey`
- `riskLevel`
- `coachSummary`
- `topFactors[]`
- `recommendedActions[]`
- `cardVersion`

### 2.4 `POST /api/sleep/enter`

用途：

- 进入睡眠模式
- 创建或更新 `sleep_sessions`
- 刷新 `sleep_mode`

请求：

```json
{
  "dormId": "optional",
  "recommendationSnapshot": [],
  "selectedRecommendationIds": []
}
```

### 2.5 `POST /api/sleep/exit`

用途：

- 结束睡眠模式
- 写入 `awaitingFeedback` 或 `completed`
- 刷新 `morning_feedback`

### 2.6 `POST /api/dream/save`

用途：

- 保存梦境记录
- 分析梦境情绪
- 更新 `profileSummary`

请求：

```json
{
  "entry": {
    "id": "dream-xxx",
    "title": "梦境标题",
    "body": "梦境正文",
    "tags": ["平静", "雨夜"]
  }
}
```

### 2.7 `POST /api/feedback/morning`

用途：

- 保存晨间反馈
- 更新 `feedbackLoop`
- 生成下一轮画像总结

### 2.8 `POST /api/dorm/create`

用途：

- 创建宿舍
- 绑定当前用户为首位成员

请求：

```json
{
  "name": "梅苑 2 栋 204",
  "overview": "我们希望一起把宿舍夜间节奏稳下来",
  "rulesSettings": {
    "quietHours": "23:00 - 07:00",
    "lightsOffTime": "23:30 后关闭主灯",
    "routineNote": "工作日 8:00 起床"
  }
}
```

返回：

```json
{
  "dormId": "dorm-xxxx",
  "name": "梅苑 2 栋 204",
  "createdAt": "2026-04-07T00:00:00.000Z",
  "memberStatus": "quiet"
}
```

### 2.9 `POST /api/dorm/invite/create`

用途：

- 为当前宿舍生成邀请码

返回：

- `inviteId`
- `inviteCode`
- `dormId`
- `createdAt`
- `expiresAt`
- `memberCountSnapshot`

### 2.10 `POST /api/dorm/invite/accept`

用途：

- 通过邀请码加入宿舍

请求：

```json
{
  "inviteCode": "DORM-AB12CD"
}
```

### 2.11 `POST /api/assistant/reply`

用途：

- Assistant 对话入口
- 记录线程消息
- 生成结构化回复

请求：

```json
{
  "threadId": "thread-xxx",
  "prompt": "我今晚有点睡不着",
  "title": "今晚睡前聊聊"
}
```

返回：

```json
{
  "reply": "中文回复",
  "runId": "run-xxx",
  "intent": "sleep_difficulty",
  "provider": "deterministic-fallback",
  "model": "rules-v1",
  "recommendedActions": [],
  "updatedSurfaces": ["assistant_context", "home_pre_sleep"]
}
```

### 2.12 `POST /api/cards/refresh`

用途：

- 指定刷新快照卡片

请求：

```json
{
  "surfaces": ["home_pre_sleep", "profile_report"]
}
```

### 2.13 `POST /api/auth/link-phone`

用途：

- 把已验证手机号绑定到当前用户资料

请求：

```json
{
  "phoneNumber": "13800138000",
  "verificationToken": "客户端校验验证码得到的 token",
  "phoneAccessToken": "手机号会话 access token"
}
```

说明：

- 后端真正校验依赖 `phoneAccessToken`
- 后端会拿它去 CloudBase 查询当前手机号
- 验证通过后，才写 `users.phoneNumber` 和 `users.phoneLinkedAt`

## 3. 事件函数

### 3.1 `on-sleep-session-write`

监听集合：

- `sleep_sessions`

监听事件：

- `insert`
- `update`

作用：

- 处理旁路写库
- 刷新 `user_state`
- 刷新 `sleep_mode` / `morning_feedback` / `assistant_context`

### 3.2 `on-dream-entry-write`

监听集合：

- `dream_entries`

监听事件：

- `insert`
- `update`

作用：

- 处理旁路写库
- 重新分析梦境
- 刷新 `profile_report` / `assistant_context`

## 4. `_automation` 元数据协议

源文档字段：

- `_automation.origin`
- `_automation.syncProcessingRequested`
- `_automation.syncRequestedAt`
- `_automation.lastDerivedAt`
- `_automation.lastDerivedBy`
- `_automation.lastHandledStatus`

用途：

- 避免同步链路和数据库触发器重复执行
- 避免纯内部字段更新导致递归触发

## 5. Firestore / NoSQL 读写责任

### 客户端可读的聚合结果

- `user_state`
- `card_snapshots`

### 客户端不直写

- `user_state`
- `card_snapshots`
- `assistant_runs`
- `dorm_invites`
- `dorm_events`

### 服务端写入

- `app-api`
- 事件触发器

## 6. AI Provider 模式

当前支持三种模式：

- `deterministic`
- `cloudbase_ai`
- `external_http`

入口：

- `functions/src/providers/provider_factory.ts`

原则：

- 不管底层模型是谁，返回给前端的必须是结构化结果
- 不允许把原始模型输出直接透传给页面
