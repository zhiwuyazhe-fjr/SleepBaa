# CloudBase Operations

最后核验日期：2026-04-29。本文以当前脚本、配置样例和 `functions/package.json` 为准。

## 本地配置

复制配置样例：

```powershell
Copy-Item .cloudbase.local.example.json .cloudbase.local.json
```

关键字段：

| 字段 | 说明 |
| --- | --- |
| `APP_BACKEND` | `in_memory`、`emulator`、`staging` 或 `production`。CloudBase 联调必须不是 `in_memory`。 |
| `CLOUDBASE_ENV_ID` | CloudBase 环境 id。 |
| `CLOUDBASE_AUTH_BASE_URL` | CloudBase Auth API base URL。 |
| `CLOUDBASE_APP_API_BASE_URL` | `app-api` HTTP Function base URL。 |
| `CLOUDBASE_PUBLISHABLE_KEY` | 客户端认证所需 publishable key。 |

Android 联调脚本会读取 `.cloudbase.local.json`：

```powershell
.\run_android_cloudbase.cmd
```

脚本会校验必填字段、选择 Android 设备，并执行：

```powershell
flutter run -d <deviceId> --dart-define-from-file=.cloudbase.local.json
```

## Flutter 本地运行

不传 CloudBase 配置时默认使用 in-memory：

```powershell
flutter pub get
flutter run
```

这种模式适合页面开发和交互调试，但不会验证 CloudBase 鉴权、远端持久化或触发器。

## Functions 测试

```powershell
npm --prefix functions install
npm --prefix functions test
```

常见测试覆盖：

- `app_api.test.ts`：HTTP route、SSE、睡眠/反馈/capture 等语义。
- `assistant_orchestrator.test.ts`：助手回复、卡片、记忆、触发器派生。
- `provider_factory.test.ts`：provider 模式、模型覆盖、错误兜底。
- `firestore_repositories_dorm.test.ts`：宿舍、音频目录、头像同步、成员心跳。
- `cloudbase_triggers.test.ts`：睡眠/梦记触发器 payload 兼容。

## 本地启动 app-api

```powershell
npm --prefix functions run serve
```

默认端口是 `9000`，可通过 `PORT` 覆盖。仅本地调试时可用 `x-debug-uid` 或 `LOCAL_DEBUG_UID` 兜底鉴权。

## 部署函数

```powershell
.\deploy_cloudbase_functions.cmd
```

部署脚本会执行以下动作：

1. `npm --prefix functions run prepare:deploy`
2. 编译 TypeScript
3. 把 `functions/lib` 复制到各函数目录
4. 写入 CloudBase function bootstrap
5. 部署：
   - `functions/app-api`
   - `functions/on-sleep-session-write`
   - `functions/on-dream-entry-write`
6. 更新函数环境变量与访问配置
7. 输出 `https://<envId>.service.tcloudbase.com/app-api`

部署脚本默认 provider 配置：

| 变量 | 默认值 |
| --- | --- |
| `AI_PROVIDER_MODE` | `cloudbase_ai` |
| `AI_PROVIDER_MODEL` | `hunyuan-2.0-instruct-20251111` |
| `AI_PROVIDER_TIMEOUT_MS` | `60000` |

## 发布前检查

```powershell
rg -n "app\.(get|post)" functions/src/http/app_api.ts
npm --prefix functions test
flutter analyze
```

如果只修改文档，可以不跑完整应用测试，但必须确认冻结文档未被改动：

```powershell
git diff -- docs/backend/cloudbase-team-manual.md docs/team_delivery_plan.md
```

## 常见问题

| 现象 | 优先检查 |
| --- | --- |
| App 一直跳 `/auth/phone` | `CLOUDBASE_AUTH_BASE_URL`、publishable key、手机号验证状态。 |
| `/api/app/bootstrap` 400 | CloudBase 集合权限、缺失集合、bootstrap diagnose。 |
| 助手流式无返回 | provider 环境变量、函数日志、SSE keepalive、超时设置。 |
| 同一线程提示忙 | 当前线程 turn lease 未释放或用户重复提交。 |
| 宿舍成员在线异常 | `dorm/member/heartbeat` 是否被调用，注意它不负责切换睡眠模式。 |
