# CloudBase 团队联调手册

最后核验日期：2026-04-29。本手册只描述当前项目真实使用的 CloudBase 联调、部署与排查方式；后端接口、数据模型和运维细节的完整说明分别见：

- [api-reference.md](api-reference.md)
- [data-model.md](data-model.md)
- [cloudbase-operations.md](cloudbase-operations.md)

本文不会要求普通成员执行会修改线上环境的 CloudBase 管理命令。涉及函数部署、网关、安全规则、集合结构的动作，默认只由环境 owner 或后端负责人执行。

## 1. 当前环境与项目链路

| 项目 | 当前值 |
| --- | --- |
| CloudBase 环境 ID | `sleep-dorm-app-9ggjkxy371d18ebe` |
| 区域 | `ap-shanghai` |
| HTTP Function | `app-api` |
| 事件函数 | `on-sleep-session-write`, `on-dream-entry-write` |
| 移动端默认联调平台 | Android |

当前链路：

```text
Flutter App
  -> CloudBase Auth 获取 access token
  -> app-api HTTP Function
  -> CloudBase NoSQL / Storage / AI provider
  -> user_state / card_snapshots / notifications / assistant memory
```

客户端只调用 `app-api`，不直接写业务集合。CloudBase 官方 HTTP 访问服务认证要求 Web/App 请求携带 `Authorization: Bearer <accessToken>`；当前 Flutter 客户端由 `CloudBaseAppApiClient` 自动处理 token 和 401 refresh。

## 2. 新成员本地准备

推荐环境：

- Node.js 20 或 22
- Flutter stable
- Android Studio
- Git
- 可用的 Android 真机或模拟器

检查命令：

```powershell
node -v
npm -v
flutter --version
flutter devices
git --version
```

只有 `flutter devices` 能看到 Android 设备时，`.\run_android_cloudbase.cmd` 才能真正安装并运行 App。

## 3. CloudBase MCP / mcporter

项目部署脚本通过 `mcporter` 调 CloudBase MCP。普通成员日常只需要做 read/status 类检查：

```powershell
npx mcporter list
npx mcporter call cloudbase.auth action=status --output json
npx mcporter call cloudbase.envQuery action=info --output json
```

如果未登录，可由需要操作 CloudBase 的成员执行设备码登录：

```powershell
npx mcporter call cloudbase.auth action=start_auth authMode=device --output json
```

绑定当前环境：

```powershell
npx mcporter call cloudbase.auth action=set_env envId=sleep-dorm-app-9ggjkxy371d18ebe --output json
```

执行任何 CloudBase 写操作前，先确认当前环境：

```powershell
npx mcporter call cloudbase.envQuery action=info --output json
```

## 4. 本地配置文件

每个成员本地准备一份 `.cloudbase.local.json`：

```powershell
Copy-Item .cloudbase.local.example.json .cloudbase.local.json
```

字段必须与 `.cloudbase.local.example.json` 保持一致：

```json
{
  "APP_BACKEND": "staging",
  "CLOUDBASE_ENV_ID": "sleep-dorm-app-9ggjkxy371d18ebe",
  "CLOUDBASE_AUTH_BASE_URL": "https://sleep-dorm-app-9ggjkxy371d18ebe.api.tcloudbasegateway.com",
  "CLOUDBASE_APP_API_BASE_URL": "https://sleep-dorm-app-9ggjkxy371d18ebe.service.tcloudbase.com/app-api",
  "CLOUDBASE_PUBLISHABLE_KEY": "替换为团队发放的 Publishable Key"
}
```

注意：

- `.cloudbase.local.json` 不提交 Git。
- Publishable Key 是环境级共享配置，不是每人一份。
- Publishable Key 可以用于客户端匿名能力，但仍属于团队配置，不应公开贴到 issue、截图或日志里。
- 管理员级 API Key、AI provider key、腾讯云 SecretId/SecretKey 不能放进 Flutter 客户端。

## 5. Android 联调

日常联调用：

```powershell
.\run_android_cloudbase.cmd
```

脚本实际执行逻辑来自 `scripts/run_android_cloudbase.ps1`：

- 读取 `.cloudbase.local.json`
- 校验 `APP_BACKEND`
- 校验 `CLOUDBASE_ENV_ID`
- 校验 `CLOUDBASE_AUTH_BASE_URL`
- 校验 `CLOUDBASE_APP_API_BASE_URL`
- 校验 `CLOUDBASE_PUBLISHABLE_KEY`
- 自动选择一台 Android 设备
- 执行 `flutter run -d <device> --dart-define-from-file=.cloudbase.local.json`

如果只做纯 UI 调整，也可以不传 CloudBase 配置，直接使用 in-memory 模式：

```powershell
flutter pub get
flutter run
```

## 6. 后端函数部署

只有改了 `functions/**`、AI provider 配置或后端函数依赖时，才需要部署函数：

```powershell
.\deploy_cloudbase_functions.cmd
```

部署脚本来自 `scripts/deploy_cloudbase_functions.ps1`，当前会处理 3 个函数：

| 函数 | 类型 | Runtime | Timeout |
| --- | --- | --- | --- |
| `app-api` | HTTP | `Nodejs18.15` | 60s |
| `on-sleep-session-write` | Event | `Nodejs18.15` | 60s |
| `on-dream-entry-write` | Event | `Nodejs18.15` | 60s |

脚本会执行：

1. `npm --prefix functions run prepare:deploy`
2. 创建或更新 3 个函数代码
3. 更新函数环境变量
4. 尝试把 `app-api` 函数安全规则设为已鉴权用户可调用
5. 如未传 `-SkipGateway`，检查并创建 `/app-api` HTTP 访问服务网关

部署后脚本会输出：

```text
CloudBase functions deployed.
app-api: https://sleep-dorm-app-9ggjkxy371d18ebe.service.tcloudbase.com/app-api
```

函数本地测试：

```powershell
npm --prefix functions test
```

本地启动 `app-api`：

```powershell
npm --prefix functions run serve
```

默认端口是 `9000`。

## 7. AI Provider 配置

当前代码支持 2 种 provider mode：

| Mode | 用途 |
| --- | --- |
| `deterministic` | 规则兜底和测试，不依赖真实模型。 |
| `cloudbase_ai` | CloudBase AI / OpenAI-compatible gateway。 |

部署脚本默认值：

| 参数 | 默认值 |
| --- | --- |
| `-AIProviderMode` | `cloudbase_ai` |
| `-AIProviderModel` | `hunyuan-2.0-instruct-20251111` |
| `-AIProviderTimeoutMs` | `60000` |

默认部署：

```powershell
.\deploy_cloudbase_functions.cmd
```

切换到 deterministic：

```powershell
.\deploy_cloudbase_functions.cmd -AIProviderMode deterministic -AIProviderModel rules-v1
```


关于 AI provider secret：

- 如果不传 `-AIProviderApiKey`，部署脚本会保留远端函数当前已有的 provider secret 值。
- 只有显式传 `-AIProviderApiKey <new-secret>` 才会覆盖远端值。
- 只有显式传 `-ClearAIProviderApiKey` 才会清空远端值。
- 不要把任何 AI provider secret 写进 `.cloudbase.local.json`、Flutter 代码、文档或 issue。

## 8. 数据库、安全规则、触发器

完整集合列表以 [data-model.md](data-model.md) 为准，不在本手册重复维护旧集合清单。

当前原则：

- Flutter 客户端不直接写业务集合。
- 业务写入统一走 `app-api`。
- 业务集合应保持后端/admin 写入模型。
- 触发器用于兜底处理 `sleep_sessions` 和 `dream_entries` 的派生逻辑。

环境 owner 可做只读检查：

```powershell
npx mcporter call "cloudbase.readNoSqlDatabaseStructure(action: 'listCollections', limit: 50)" --output json
npx mcporter call "cloudbase.queryFunctions(action: 'listFunctions')" --output json
npx mcporter call "cloudbase.queryFunctions(action: 'listFunctionTriggers', functionName: 'on-sleep-session-write')" --output json
npx mcporter call "cloudbase.queryFunctions(action: 'listFunctionTriggers', functionName: 'on-dream-entry-write')" --output json
```

创建集合、写安全规则、创建/删除触发器、创建网关都属于 owner-only 写操作。普通成员不要自行执行；如果必须调整，先在群里确认目标环境、变更内容和回滚方式。

## 9. 当前核心业务接口

完整接口表见 [api-reference.md](api-reference.md)。团队联调时最常关注的链路：

| 流程 | 主要接口 |
| --- | --- |
| 启动快照 | `POST /api/app/bootstrap` |
| 保存用户/设置 | `POST /api/profile/save` |
| 夜间情绪与今晚计划 | `POST /api/profile/night-mood` |
| 进入/暂停/退出睡眠 | `POST /api/sleep/enter`, `POST /api/sleep/pause`, `POST /api/sleep/exit` |
| 晨间反馈 | `POST /api/feedback/morning` |
| 梦记与事记 | `POST /api/dream/save`, `POST /api/sleep-capture/save` |
| 宿舍协作 | `POST /api/dorm/create`, `POST /api/dorm/invite/create`, `POST /api/dorm/invite/accept`, `POST /api/dorm/member/status` |
| 助手 | `POST /api/assistant/reply/stream`, `POST /api/assistant/capture/stream` |
| 卡片刷新 | `POST /api/cards/refresh` |

Legacy 接口说明：

- `/api/auth/recover-phone-account` 当前返回 410 `LEGACY_DISABLED`。
- `/api/auth/link-phone` 当前返回 410 `LEGACY_DISABLED`。
- 新登录/注册/重置密码流程走当前 CloudBase Auth 客户端和手机号验证逻辑，不走 legacy BFF。

## 10. 日常排查

### App 一直进 `/auth/phone`

优先检查：

1. `.cloudbase.local.json` 是否存在。
2. `CLOUDBASE_AUTH_BASE_URL` 是否是当前环境。
3. `CLOUDBASE_PUBLISHABLE_KEY` 是否为团队发放的真实值。
4. 当前账号是否完成手机号身份验证。

### `bootstrap` 失败

优先检查：

```powershell
npm --prefix functions run serve
```

然后对照 [api-reference.md](api-reference.md) 和函数日志确认 `/api/app/bootstrap` 的错误信息。若怀疑集合或权限问题，环境 owner 再做 CloudBase 只读检查。

### Android 没有安装或没有设备

先跑：

```powershell
flutter devices
```

没有 Android 真机或模拟器时，`.\run_android_cloudbase.cmd` 会直接失败。

### 改了 Flutter 页面但线上行为没变

如果只改 `lib/**`，不需要部署函数；重新运行 App 即可。只有改 `functions/**` 或函数环境变量时才跑 `.\deploy_cloudbase_functions.cmd`。

### 助手没有真实模型回复

优先确认：

- 3 个函数上的 `AI_PROVIDER_MODE`
- `AI_PROVIDER_MODEL`
- provider secret 是否为 `set`
- 函数日志中的 provider 错误

不要把 provider secret 复制到文档或聊天里。

## 11. 团队协作约定

不要提交：

- `.cloudbase.local.json`
- 本地临时日志
- 真实 Publishable Key 截图
- AI provider secret
- 腾讯云 SecretId / SecretKey

推荐提交前检查：

```powershell
git status --short
git diff --check
```

提交前还需要人工确认没有把真实长 token、密钥、验证码或个人配置贴进文档、截图和 issue。

## 12. 官方依据

- CloudBase HTTP 访问服务认证：https://docs.cloudbase.net/en/service/authentication
- CloudBase HTTP API 域名说明：https://docs.cloudbase.net/en/http-api/basic/overview
- CloudBase 网关权限控制：https://docs.cloudbase.net/en/authentication-v2/auth/auth-gateway
- CloudBase MCP 工具：https://docs.cloudbase.net/ai/cloudbase-ai-toolkit/mcp-tools
