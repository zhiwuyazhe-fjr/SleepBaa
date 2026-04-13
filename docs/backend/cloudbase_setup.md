# CloudBase 部署与联调清单

## 1. 基础环境

先确认当前账号已经登录并绑定到了目标环境：

```bash
npx mcporter call cloudbase.auth action=status --output json
```

如果还没登录：

```bash
npx mcporter call cloudbase.auth action=start_auth authMode=device --output json
```

登录后绑定环境：

```bash
npx mcporter call cloudbase.auth action=set_env envId=<你的-envId> --output json
```

再次检查时，期望看到：

- `auth_status = AUTHORIZED`
- `env_status = READY`

## 2. Flutter 运行环境变量

建议至少带上下面这些 `dart-define`：

```bash
--dart-define=APP_BACKEND=staging
--dart-define=CLOUDBASE_ENV_ID=<envId>
--dart-define=CLOUDBASE_AUTH_BASE_URL=https://<envId>.api.tcloudbasegateway.com
--dart-define=CLOUDBASE_APP_API_BASE_URL=https://<你的-app-api-域名>
--dart-define=CLOUDBASE_PUBLISHABLE_KEY=<publishable_key>
```

如果 `APP_BACKEND=in_memory`，或者 `CLOUDBASE_APP_API_BASE_URL` 没配，App 会明确提示“当前未写入云端”。

## 3. Functions 运行环境变量

```bash
CLOUDBASE_ENV_ID=<envId>
AI_PROVIDER_MODE=deterministic
AI_PROVIDER_NAME=cloudbase_ai
AI_PROVIDER_MODEL=hunyuan-2.0-instruct-20251111
AI_PROVIDER_TIMEOUT_MS=12000
```

如果你要用固定 env 音频兜底，可以额外配置：

```bash
SLEEP_AUDIO_DEEP_OCEAN_FILE_ID=
SLEEP_AUDIO_DEEP_OCEAN_URL=
SLEEP_AUDIO_RAIN_MIST_FILE_ID=
SLEEP_AUDIO_RAIN_MIST_URL=
SLEEP_AUDIO_MIDNIGHT_BREEZE_FILE_ID=
SLEEP_AUDIO_MIDNIGHT_BREEZE_URL=
```

这些现在只是 fallback，主方案已经切到 `audio_tracks` 集合。

## 4. 需要的集合

至少准备这些集合：

- `users`
- `user_settings`
- `user_state`
- `card_snapshots`
- `assistant_runs`
- `sleep_sessions`
- `dream_entries`
- `sleep_capture_records`
- `assistant_threads`
- `assistant_messages`
- `notifications`
- `dorms`
- `dorm_members`
- `dorm_events`
- `dorm_invites`
- `audio_tracks`

## 5. 云端音频接入

### 5.1 Storage 目录建议

建议在 CloudBase Storage 中建立目录：

```text
audio/sleep/
```

示例文件：

- `audio/sleep/deep-ocean.mp3`
- `audio/sleep/rain-mist.mp3`
- `audio/sleep/midnight-breeze.mp3`

上传后记下每个文件的 `fileID`。

### 5.2 `audio_tracks` 集合结构

每条音频至少包含这些字段：

```json
{
  "id": "deep-ocean",
  "title": "深海海浪",
  "subtitle": "低刺激白噪音 · 45 分钟",
  "durationSeconds": 2700,
  "storageFileId": "cloud://<envId>.xxx/audio/sleep/deep-ocean.mp3",
  "enabled": true,
  "sortOrder": 10,
  "tags": ["放松", "白噪音"],
  "createdAt": "2026-04-12T12:00:00.000Z",
  "updatedAt": "2026-04-12T12:00:00.000Z"
}
```

当前后端逻辑：

1. 先查 `audio_tracks`
2. 只读取 `enabled = true`
3. 按 `sortOrder` 升序返回
4. 用 `storageFileId` 生成临时播放 URL
5. 如果集合里没有可用音频，再回退到 `SLEEP_AUDIO_*` 环境变量

### 5.3 新增一首音频的最短流程

1. 把音频上传到 `audio/sleep/`
2. 复制它的 `fileID`
3. 在 `audio_tracks` 里新增一条记录
4. 保证 `enabled = true`
5. 部署函数
6. 打开 App 检查首页推荐卡是否拉到新音频

## 6. App API 与函数部署

本地构建：

```bash
npm --prefix functions install
npm --prefix functions run build
```

准备部署物料：

```bash
npm --prefix functions run prepare:deploy
```

当前重要接口包括：

- `POST /api/app/bootstrap`
- `POST /api/media/audio-catalog`
- `POST /api/dorm/location-anchor`
- `POST /api/dorm/environment`
- `POST /api/dorm/member/status`
- `POST /api/interference/tonight`

## 7. 自检步骤

### 7.1 音频目录

部署完函数后，先验证：

```bash
curl -X POST https://<你的-app-api-域名>/api/media/audio-catalog \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d "{}"
```

检查返回：

- `tracks` 数组不为空
- 每条记录都有 `id`
- 每条记录最好都带 `sourceUrl`

### 7.2 宿舍定位

在 Android 上重新记录一次宿舍位置后：

1. 杀后台
2. 重新打开 App
3. 进入设置页确认仍显示“已记录宿舍坐标”
4. 若前台重新定位成功，宿舍状态会同步成“已返 / 未返”

### 7.3 今晚影响因素

验证以下行为：

- 首页点击“宿舍噪声”会申请麦克风权限并更新结果
- 首页点击“灯光环境”会申请前摄权限并更新结果
- 首页点击“手机使用”会跳到 Usage Access 授权页并回读近 2 小时使用时长
- 详情页首次进入会自动检测噪声、灯光和手机使用
- 检测结果会通过 `/api/interference/tonight` 写回

## 8. 当前实现结论

当前云端音频链路已经是正确方向：

- Flutter 只依赖 `AudioTrack.sourceUrl`
- 后端通过 `/api/media/audio-catalog` 返回可播地址
- Storage 文件通过 `storageFileId` 动态换取临时 URL

相比之前固定 3 首环境变量，现在你可以在 CloudBase 里自己增删音频，不需要重新打包 App。
