# CloudBase 快速启动

先看 [cloudbase_team_manual.md](./cloudbase_team_manual.md)。

这份文档只保留最短启动路径。

## 1. 先确认状态

```powershell
npx mcporter call cloudbase.auth action=status --output json
```

预期：

- `auth_status = READY`
- `env_status = READY`
- `current_env_id = sleep-dorm-app-9ggjkxy371d18ebe`

## 2. 先部署函数

```powershell
.\deploy_cloudbase_functions.cmd
```

部署后检查：

```powershell
npx mcporter call cloudbase.queryFunctions action=listFunctions --output json
```

预期 3 个函数都是 `Active`：

- `app-api`
- `on-sleep-session-write`
- `on-dream-entry-write`

## 3. 再跑 Android

```powershell
.\run_android_cloudbase.cmd
```

等价于：

```powershell
flutter run -d android --dart-define-from-file=.cloudbase.local.json
```

## 4. 本轮不用 MySQL

当前 MVP 全部走：

- CloudBase Auth
- `app-api` HTTP Function
- CloudBase NoSQL

## 5. 真自动触发

控制台里记得配两条数据库触发器：

1. `sleep_sessions`
   - 事件：`insert`、`update`
   - 函数：`on-sleep-session-write`

2. `dream_entries`
   - 事件：`insert`、`update`
   - 函数：`on-dream-entry-write`

## 6. 遇到问题先查这里

- 完整操作手册：[cloudbase_team_manual.md](./cloudbase_team_manual.md)
- 团队分工：[team_delivery_plan.md](./team_delivery_plan.md)
