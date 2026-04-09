# CloudBase 团队总手册

这份文档是当前项目接入 CloudBase 真环境的唯一主手册。

说明：

- 当前运行主线已经切到 CloudBase。
- `docs/backend/firebase_setup.md` 保留不动，只作为历史文档，不再作为运行指南。
- 当前 MVP 不需要 MySQL，全部业务数据继续使用 CloudBase NoSQL + HTTP Function。
- 同一个 CloudBase 环境下，`Publishable Key` 是环境级共享配置，整个团队共用一份，不是每个人一份。
- 当前默认联调平台是 Android。

## 1. 当前环境信息

- 环境 ID：`sleep-dorm-app-9ggjkxy371d18ebe`
- 区域：`ap-shanghai`
- HTTP Function：`app-api`
- 事件函数：
  - `on-sleep-session-write`
  - `on-dream-entry-write`

项目主链路：

1. Flutter 客户端先通过 CloudBase Auth HTTP API 完成匿名登录或手机号验证。
2. 客户端只调用 `app-api`，不直连业务库。
3. `app-api` 负责读写 NoSQL、执行 AI 编排、回写 `user_state` 和 `card_snapshots`。
4. `sleep_sessions`、`dream_entries` 再通过数据库触发器做兜底自动处理。

## 2. 当前必须知道的结论

### 2.1 不需要 MySQL

这版 MVP 不开 MySQL。

原因：

- 业务数据本质是用户画像、今晚计划、卡片快照、睡眠记录、梦境记录、宿舍协作记录，天然更适合文档结构。
- Flutter 侧已经改成只调 `app-api`，不需要在端上直连 SQL。
- 当前目标是尽快跑通“登录 -> 今晚建议 -> 睡眠模式 -> 梦境 -> 晨间反馈 -> Assistant 对话”的闭环。

### 2.2 Publishable Key 规则

- 同一个环境只需要一份 `Publishable Key`
- `staging` 和 `production` 各自一份
- 队员本地 `.cloudbase.local.json` 里填同一份即可
- 不要把真实 key 提交进 Git


## 3. 新队员第一次接手时要做什么

## 3.1 安装本机依赖

Windows 建议安装：

- Node.js 20 或 22
- Flutter stable
- Android Studio
- Git

命令检查：

```powershell
node -v
npm -v
flutter --version
git --version
```

## 3.2 检查 `mcporter`

项目默认通过本机已配置的 CloudBase MCP 来管理真环境。

先跑：

```powershell
npx mcporter list
```

如果能看到 `cloudbase`，说明 MCP 已可用。

## 3.3 CloudBase 登录

查看当前状态：

```powershell
npx mcporter call cloudbase.auth action=status --output json
```

如果没有登录，执行：

```powershell
npx mcporter call cloudbase.auth action=start_auth authMode=device --output json
```

按终端提示，在浏览器完成授权。

## 3.4 绑定项目环境

```powershell
npx mcporter call cloudbase.auth action=set_env envId=sleep-dorm-app-9ggjkxy371d18ebe --output json
```

然后再检查：

```powershell
npx mcporter call cloudbase.envQuery action=info --output json
```

预期：

- 当前环境是 `sleep-dorm-app-9ggjkxy371d18ebe`
- 区域是上海
- 环境状态正常

## 4. 控制台里要手动确认的配置

## 4.1 打开登录方式

控制台路径：

1. 进入 CloudBase 控制台
2. 切换到环境 `sleep-dorm-app-9ggjkxy371d18ebe`
3. 打开“身份认证”
4. 进入“登录方式管理”

必须打开：

- 匿名登录
- 手机号登录

## 4.2 生成 Publishable Key

仍在身份认证相关页面里生成或查看 `Publishable Key`。

拿到后，把它分发给队员填进本地配置文件，不要提交 Git。

## 5. 本地配置文件

项目根目录需要有：

- `.cloudbase.local.example.json`
- `.cloudbase.local.json`

推荐做法：

1. 复制一份示例文件
2. 命名为 `.cloudbase.local.json`
3. 填入真实值

标准内容：

```json
{
  "APP_BACKEND": "staging",
  "CLOUDBASE_ENV_ID": "sleep-dorm-app-9ggjkxy371d18ebe",
  "CLOUDBASE_AUTH_BASE_URL": "https://sleep-dorm-app-9ggjkxy371d18ebe.api.tcloudbasegateway.com",
  "CLOUDBASE_APP_API_BASE_URL": "https://sleep-dorm-app-9ggjkxy371d18ebe.service.tcloudbase.com/app-api",
  "CLOUDBASE_PUBLISHABLE_KEY": "替换成真实 publishable key"
}
```

注意：

- `.cloudbase.local.json` 已加入忽略列表
- 每个队员都要自己本地准备一份

## 6. 首次初始化环境清单

这些只需要咱们一个人做，我已经做了，但是如果有人改了 functions/**，那改后端的人需要重新执行 .\deploy_cloudbase_functions.cmd

## 6.1 创建 14 个集合

固定集合：

- `users`
- `user_settings`
- `user_state`
- `card_snapshots`
- `assistant_runs`
- `sleep_sessions`
- `dream_entries`
- `assistant_threads`
- `assistant_messages`
- `notifications`
- `dorms`
- `dorm_members`
- `dorm_events`
- `dorm_invites`

查看已有集合：

```powershell
npx mcporter call cloudbase.readNoSqlDatabaseStructure action=listCollections limit=30 --output json
```

补建单个集合：

```powershell
npx mcporter call cloudbase.writeNoSqlDatabaseStructure action=createCollection collectionName=users --output json
```

## 6.2 设置数据库安全规则

当前项目要求：

- 客户端不直接写业务集合
- 所有业务集合默认 `ADMINWRITE`
- 客户端只通过 `app-api` 间接读写数据

检查某个集合规则：

```powershell
npx mcporter call cloudbase.readSecurityRule resourceType=noSqlDatabase resourceId=user_state --output json
```

写入规则：

```powershell
npx mcporter call cloudbase.writeSecurityRule resourceType=noSqlDatabase resourceId=user_state aclTag=ADMINWRITE --output json
```

首次初始化时，14 个集合都设置成 `ADMINWRITE`。

## 6.3 部署函数

项目根目录执行：

```powershell
.\deploy_cloudbase_functions.cmd
```

这个脚本会做：

- 编译 `functions/`
- 同步编译产物到 3 个函数目录
- 更新函数代码
- 更新函数环境变量
- 确保 `app-api` 网关存在
- 确保 `app-api` 只允许已鉴权用户调用

部署后检查：

```powershell
npx mcporter call cloudbase.queryFunctions action=listFunctions --output json
```

预期要看到：

- `app-api` 状态 `Active`
- `on-sleep-session-write` 状态 `Active`
- `on-dream-entry-write` 状态 `Active`

## 6.4 检查 `app-api` 网关

```powershell
npx mcporter call cloudbase.queryGateway action=getAccess targetType=function targetName=app-api --output json
```

预期：

- 存在 `/app-api`
- URL 可访问
- 开启鉴权

## 7. 数据库触发器怎么配
这个我也已经做了，大家不用做了。

这是最容易漏掉的一步。

当前脚本不会自动给你创建数据库触发器，所以第一次接环境时必须手动在控制台配置。

### 7.1 `sleep_sessions` 触发器

控制台路径：

1. 进入 CloudBase 控制台
2. 切环境 `sleep-dorm-app-9ggjkxy371d18ebe`
3. 打开“云数据库”
4. 找到集合 `sleep_sessions`
5. 进入“触发器”
6. 点击“新建触发器”

填写：

- 触发事件：`insert`、`update`
- 目标函数：`on-sleep-session-write`

保存即可。

### 7.2 `dream_entries` 触发器

同样步骤再配一条：

- 集合：`dream_entries`
- 触发事件：`insert`、`update`
- 目标函数：`on-dream-entry-write`

### 7.3 怎么验证触发器已经生效

验证方式：

1. 在控制台手动修改一条 `sleep_sessions` 文档
2. 查看 `on-sleep-session-write` 的日志
3. 再手动修改一条 `dream_entries` 文档
4. 查看 `on-dream-entry-write` 的日志

如果日志有触发记录，说明配置成功。

## 8. 日常开发最短命令

平时最常用就两条：

```powershell
.\deploy_cloudbase_functions.cmd
.\run_android_cloudbase.cmd
```

## 8.1 跑 Android

```powershell
.\run_android_cloudbase.cmd
```

它会：

- 读取 `.cloudbase.local.json`
- 自动找一台可用 Android 设备
- 执行 `flutter run --dart-define-from-file=.cloudbase.local.json`

如果没有安装到手机或模拟器，先检查：

```powershell
flutter devices
```

必须先看到 Android 设备。

## 8.2 改了后端后重新部署

```powershell
.\deploy_cloudbase_functions.cmd
```

如果只是改了 Flutter 页面或 `lib/core/**`，不需要重新部署函数。

## 9. Android 侧最小 MVP 验收顺序

按这个顺序走：

1. App 启动
2. 匿名登录成功
3. `bootstrap` 成功返回
4. 保存夜间心情
5. 后端生成今晚建议
6. 进入睡眠模式
7. 写入 `sleep_sessions`
8. 记录梦境
9. 写入 `dream_entries`
10. 提交晨间反馈
11. 更新 `feedbackLoop`
12. 发送 assistant prompt
13. 返回 `reply + runId + updatedSurfaces`

## 10. 这轮已经接好的关键接口

客户端当前统一走这些 BFF：

- `POST /api/app/bootstrap`
- `POST /api/profile/save`
- `POST /api/profile/night-mood`
- `POST /api/sleep/enter`
- `POST /api/sleep/exit`
- `POST /api/dream/save`
- `POST /api/feedback/morning`
- `POST /api/dorm/create`
- `POST /api/dorm/invite/create`
- `POST /api/dorm/invite/accept`
- `POST /api/assistant/reply`
- `POST /api/cards/refresh`
- `POST /api/auth/link-phone`

其中新增和本轮重点相关的是：

- `POST /api/dorm/create`
- `POST /api/auth/link-phone`

## 11. 手机号绑定链路

设置页现在走的是这条链：

1. 客户端调用 CloudBase Auth 发送验证码
2. 客户端校验验证码，拿到 `verificationToken`
3. 客户端再通过手机号会话换到 `phoneAccessToken`
4. 客户端调用 `POST /api/auth/link-phone`
5. `app-api` 用 `phoneAccessToken` 去 CloudBase 验证手机号
6. 验证通过后写入 `users.phoneNumber` 和 `users.phoneLinkedAt`

注意：

- 这轮做的是“已验证手机号绑定到当前业务资料”
- 不是做匿名账号升级或账号合并
- 当前 App 会自动把 `13800138000` 这种输入格式归一化成 `+86 13800138000`
- 如果你手动在控制台测试 CloudBase Auth 接口，也要按 `+86 13800138000` 的格式传手机号

两者区别：

- “绑定到当前资料”只是在当前匿名用户资料上写入 `phoneNumber` 和 `phoneLinkedAt`
- 这样做可以显示手机号、做通知和后续联系，但卸载重装后不能直接靠手机号找回原来的匿名数据
- “匿名账号升级/合并账号”则是把当前匿名身份正式迁移成手机号身份，或者把旧匿名数据合并到手机号主账号
- 如果后面要支持“换手机/重装后用手机号找回原数据”，下一阶段要补账号 linking / 数据迁移方案，本轮 MVP 先不做这一步

## 12. 宿舍创建 / 加入链路

宿舍邀请页现在支持两条首轮流：

### 12.1 创建宿舍

1. 填宿舍名称
2. 可选填简介、安静时段、熄灯时间、作息备注
3. 调 `POST /api/dorm/create`
4. 创建成功后直接生成邀请码

### 12.2 加入宿舍

1. 输入邀请码
2. 调 `POST /api/dorm/invite/accept`
3. 成功后刷新当前宿舍快照

注意：

- 后端不会再强行给新用户自动绑定默认宿舍
- `user.dormId` 现在允许为 `null`

## 13. AI Provider 怎么切

默认模式：

```text
AI_PROVIDER_MODE=deterministic
```

这意味着：

- 没有真实 AI 密钥时也能跑通 MVP
- 今晚建议、梦境分析、晨间反馈、assistant 回复都会有 deterministic fallback

### 13.1 切到 CloudBase AI

```powershell
.\deploy_cloudbase_functions.cmd -AIProviderMode cloudbase_ai -AIProviderModel hunyuan-2.0-instruct-20251111
```

### 13.2 切到外部 HTTP AI

```powershell
.\deploy_cloudbase_functions.cmd `
  -AIProviderMode external_http `
  -AIProviderBaseUrl https://your-ai-gateway.example.com `
  -AIProviderApiKey your_api_key `
  -AIProviderModel your_model_name
```

真实 AI 接入点固定在云端：

- `functions/src/providers/provider_factory.ts`

推荐的加 key 方式有两种：

1. 用部署脚本统一写入三个函数的环境变量

```powershell
.\deploy_cloudbase_functions.cmd `
  -AIProviderMode external_http `
  -AIProviderBaseUrl https://your-ai-gateway.example.com `
  -AIProviderApiKey your_api_key `
  -AIProviderModel your_model_name
```

2. 在 CloudBase 控制台手动填写环境变量

控制台路径：

1. 进入 CloudBase 控制台
2. 切换环境 `sleep-dorm-app-9ggjkxy371d18ebe`
3. 打开“云函数”
4. 分别进入 `app-api`、`on-sleep-session-write`、`on-dream-entry-write`
5. 打开“函数配置”或“环境变量”
6. 填入下面这些变量并保存

需要的变量：

- `AI_PROVIDER_MODE`
- `AI_PROVIDER_BASE_URL`
- `AI_PROVIDER_API_KEY`
- `AI_PROVIDER_MODEL`
- `AI_PROVIDER_TIMEOUT_MS`

如果你用的是 CloudBase 自带 AI，不一定要填外部 `AI_PROVIDER_API_KEY`，通常只需要：

- `AI_PROVIDER_MODE=cloudbase_ai`
- `AI_PROVIDER_MODEL=hunyuan-2.0-instruct-20251111`

不要把 AI key 放进 Flutter 客户端。

## 14. 常见问题排查

### 14.1 匿名登录失败

先检查：

1. 控制台是否开启匿名登录
2. `.cloudbase.local.json` 里的 `CLOUDBASE_PUBLISHABLE_KEY` 是否真实且属于当前环境
3. App 是否使用了正确的 `staging` 配置

### 14.2 `app-api` 返回 401

优先检查：

1. 客户端是否真的完成了匿名登录
2. `app-api` 网关是否开启鉴权
3. `app-api` 安全规则是否是 `auth != null`

### 14.3 函数状态一直是 `Updating`

直接重跑：

```powershell
.\deploy_cloudbase_functions.cmd
```

当前脚本已经带重试逻辑。

### 14.4 手机号验证码发送失败

优先检查：

1. 控制台“身份认证”里是否已经打开手机号登录
2. 手机号是否使用了 `+86 13800138000` 这种格式
3. 如果 App 里直接输入 `13800138000`，当前代码会自动补成 `+86 13800138000`
4. 如果还是失败，检查 CloudBase 手机短信通道是否已经开通、配额是否充足

### 14.5 Android 没有安装到设备

先跑：

```powershell
flutter devices
```

只有当这里能看到 Android 真机或模拟器时，`.\run_android_cloudbase.cmd` 才会真正安装 App。

### 14.5 触发器没反应

先确认：

1. 控制台里真的给 `sleep_sessions` 配了触发器
2. 控制台里真的给 `dream_entries` 配了触发器
3. 目标函数名称没有选错
4. 去对应函数日志里看是否被触发

## 15. 队员协作约定

不要提交：

- `.cloudbase.local.json`
- 本地临时日志
- 个人私有密钥

可以提交：

- `functions/**`
- `lib/core/**`
- 允许修改的页面文件
- `docs/**`

不要碰：

- `docs/backend/firebase_setup.md`
- 未授权的 `lib/features/**/presentation` 页面

## 16. 每天最常用的两条命令

```powershell
.\deploy_cloudbase_functions.cmd
.\run_android_cloudbase.cmd
```


另外：
(我已经添加)
放 CloudBase 云函数环境变量里。最稳的是直接用部署脚本：

.\deploy_cloudbase_functions.cmd `
  -AIProviderMode external_http `
  -AIProviderBaseUrl https://api.x.ai/v1/responses `
  -AIProviderApiKey xxxxx `
  -AIProviderModel xxxxx
如果你想在控制台手动加：

进入 CloudBase 控制台
切到环境 sleep-dorm-app-9ggjkxy371d18ebe
打开“云函数”
分别进入 app-api、on-sleep-session-write、on-dream-entry-write
在“函数配置/环境变量”里填：
AI_PROVIDER_MODE
AI_PROVIDER_BASE_URL
AI_PROVIDER_API_KEY
AI_PROVIDER_MODEL
AI_PROVIDER_TIMEOUT_MS


如果你之后想改成 deepseek-v3.2，只需要这一条：
.\scripts\deploy_cloudbase_functions.ps1 -ConfigPath .cloudbase.local.json -AIProviderModel "deepseek-v3.2"
