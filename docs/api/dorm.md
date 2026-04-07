# Dorm 模块接口

## 1. Flutter 入口

- `DormFacade.createDorm(...)`
- `DormFacade.createInvite()`
- `DormFacade.acceptInvite(inviteCode)`
- `DormFacade.saveRules(settings)`
- `DormFacade.updateCurrentUserStatus(...)`

## 2. 当前产品规则

- 新用户不再自动绑定默认宿舍
- `user.dormId` 现在允许为 `null`
- 宿舍邀请页负责“创建宿舍 / 加入宿舍 / 生成邀请码”完整首轮流
- 宿舍页只保留“邀请舍友”入口，不重做主页布局

## 3. 当前后端路由

### 3.1 `POST /api/dorm/create`

用途：

- 创建宿舍
- 当前用户成为第一位成员

请求：

```json
{
  "name": "梅苑 2 栋 204",
  "overview": "希望一起把夜间作息稳下来",
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

### 3.2 `POST /api/dorm/invite/create`

用途：

- 为当前宿舍生成邀请码

返回：

- `inviteId`
- `inviteCode`
- `dormId`
- `createdAt`
- `expiresAt`
- `memberCountSnapshot`

### 3.3 `POST /api/dorm/invite/accept`

用途：

- 通过邀请码加入宿舍

请求：

```json
{
  "inviteCode": "DORM-AB12CD"
}
```

返回：

```json
{
  "dormId": "dorm-xxxx",
  "acceptedAt": "2026-04-07T00:00:00.000Z"
}
```

## 4. 当前集合

### `dorms`

核心字段：

- `name`
- `overview`
- `noiseDb`
- `lightLabel`
- `quietLabel`
- `rulesSettings`
- `rules`

### `dorm_members`

核心字段：

- `dormId`
- `uid`
- `name`
- `status`
- `sleepModeActive`
- `note`
- `lastActiveAt`

### `dorm_events`

核心字段：

- `dormId`
- `type`
- `title`
- `detail`
- `createdAt`
- `actorUid`

### `dorm_invites`

核心字段：

- `dormId`
- `code`
- `createdByUid`
- `createdAt`
- `expiresAt`
- `status`
- `acceptedByUid`
- `acceptedAt`

## 5. 前端接线说明

- `DormPage`
  - 只负责入口展示
- `DormInvitePage`
  - 负责创建 / 加入 / 邀请完整首轮流
- `SettingsPage`
  - 不再承载邀请码生成和加入逻辑

## 6. 当前已知边界

- 旧测试账号可能有历史默认宿舍，后端会尽量识别为“未正式绑定”
- 邀请码失效治理和更多宿舍通知还在后续增强范围
- 这轮不新增宿舍主页布局，只补主链路可用性
