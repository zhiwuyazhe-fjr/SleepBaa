# CloudBase 部署与联调指南

## 1. 先确认 MCP 状态

本机已经能识别 CloudBase MCP，但如果还没登录，需要先执行：

```bash
npx mcporter call cloudbase.auth action=status --output json
```

如果返回：

- `auth_status = REQUIRED`
- `env_status = NONE`

说明还没有登录和绑定环境。

## 2. 登录并绑定环境

### 设备码登录

```bash
npx mcporter call cloudbase.auth action=start_auth authMode=device --output json
```

按返回的链接或设备码完成登录。

### 绑定环境

```bash
npx mcporter call cloudbase.auth action=set_env envId=<你的-envId> --output json
```

### 再次检查

```bash
npx mcporter call cloudbase.auth action=status --output json
```

期望：

- `auth_status = AUTHORIZED`
- `env_status = READY`

## 3. 打开登录能力

### 读取当前配置

用 MCP 或 OpenAPI 调用：

- `service=tcb`
- `action=DescribeLoginConfig`

### 修改配置

至少打开：

- `AnonymousLogin = true`
- `PhoneNumberLogin = true`

如果要短信验证码：

- `SmsVerificationConfig.Type = default`

## 4. 创建密钥

至少准备两个：

- `publishable key`
  - 给 Flutter 匿名登录、验证码发送用
- `API key`
  - 给服务端管理或平台级调用用

如果控制台还没有 `publishable key`，在身份认证 / Token 管理里创建。

## 5. 创建集合

本项目当前需要这些集合：

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

## 6. 推荐的环境变量

### Flutter 运行时

```bash
--dart-define=APP_BACKEND=staging
--dart-define=CLOUDBASE_ENV_ID=<envId>
--dart-define=CLOUDBASE_AUTH_BASE_URL=https://<envId>.api.tcloudbasegateway.com
--dart-define=CLOUDBASE_APP_API_BASE_URL=https://<你的-app-api-访问域名>
--dart-define=CLOUDBASE_PUBLISHABLE_KEY=<publishable_key>
```

### Functions 运行时

```bash
CLOUDBASE_ENV_ID=<envId>
AI_PROVIDER_MODE=deterministic
AI_PROVIDER_NAME=cloudbase_ai
AI_PROVIDER_MODEL=hunyuan-2.0-instruct-20251111
AI_PROVIDER_BASE_URL=
AI_PROVIDER_API_KEY=
AI_PROVIDER_TIMEOUT_MS=12000
```

## 7. 部署函数

### 本地构建

```bash
npm --prefix functions install
npm --prefix functions run build
```

### HTTP Function：`app-api`

部署目录：

- `functions/app-api`

入口文件：

- `functions/app-api/index.js`

启动脚本：

- `functions/app-api/scf_bootstrap`

### Event Function

部署目录：

- `functions/on-sleep-session-write`
- `functions/on-dream-entry-write`

## 8. 函数网关

`app-api` 部署后，需要给它开 HTTP 访问地址，并要求鉴权。

建议：

- 网关开启鉴权
- 客户端统一通过 `Authorization: Bearer <access_token>` 调用
- 不要把数据库写权限直接下放给 Flutter

## 9. AI 从哪里接入

固定接入点在云端：

- `functions/src/providers/provider_factory.ts`

不要在 Flutter 客户端放 AI key。

### 三种模式

- `AI_PROVIDER_MODE=deterministic`
  - 无密钥时先跑通 MVP
- `AI_PROVIDER_MODE=external_http`
  - 接你们自己的外部模型服务
- `AI_PROVIDER_MODE=cloudbase_ai`
  - 直接用 CloudBase AI

## 10. 如何切真实 AI

### 外部 HTTP

设置：

- `AI_PROVIDER_MODE=external_http`
- `AI_PROVIDER_BASE_URL=<你的 AI 网关>`
- `AI_PROVIDER_API_KEY=<你的 key>`
- `AI_PROVIDER_MODEL=<模型名>`

### CloudBase AI

设置：

- `AI_PROVIDER_MODE=cloudbase_ai`
- `CLOUDBASE_ENV_ID=<envId>`
- `AI_PROVIDER_MODEL=hunyuan-2.0-instruct-20251111`

## 11. Android 联调验收顺序

1. 启动 App
2. 确认匿名会话已创建
3. 进入首页后拉到 bootstrap 数据
4. 保存 night mood
5. 看今晚建议是否刷新
6. 进入睡眠模式
7. 提交梦境
8. 提交晨间反馈
9. 发 assistant prompt

