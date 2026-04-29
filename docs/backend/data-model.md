# Data Model

最后核验日期：2026-04-29。本文以 `functions/src/repositories/firestore_repositories.ts`、`functions/src/shared/types.ts`、`lib/core/models/app_models.dart` 与 `lib/core/data/model_serializers.dart` 为准。

## Bootstrap Payload

`/api/app/bootstrap` 返回 `AppBootstrapPayload`，Flutter 端通过 `CloudBaseBootstrapSnapshot.fromPayload` 和 `ModelSerializers` 写入本地仓库快照。

| 字段 | 说明 |
| --- | --- |
| `assistantProfile` | 当前用户的助手人格与昵称设置。 |
| `user` | 用户资料、头像、手机号验证状态等。 |
| `settings` | 用户设置，包含睡眠、提醒、夜间情绪、徽章偏好等。 |
| `dorm` | 宿舍、成员、规则、事件、邀请等快照。 |
| `sleepSessions` | 睡眠会话列表。 |
| `dreamEntries` | 梦记列表与 AI 分析结果。 |
| `sleepCaptureRecords` | 助手整理的梦记/事记记录。 |
| `notifications` | 通知中心列表。 |
| `assistantThreads` | 助手线程摘要。 |
| `assistantMessages` | 按线程组织的助手消息。 |
| `cardSnapshots` | 页面 surface 卡片快照。 |
| `userState` | 首页 banner、助手上下文、临时 UI 状态等。 |

## CloudBase Collections

集合名称来自 `Collections` 常量。

| Collection | 主要内容 |
| --- | --- |
| `users` | 用户资料、头像、手机号身份等。 |
| `user_settings` | 用户设置与偏好。 |
| `user_state` | 页面临时状态、pending banner、最近上下文。 |
| `card_snapshots` | 各 surface 的物化卡片。 |
| `assistant_runs` | AI 调用记录、provider 元数据、错误信息。 |
| `assistant_profiles` | 助手人格配置。 |
| `assistant_thread_summaries` | 助手线程标题、当前 turn lease、最近消息摘要。 |
| `assistant_messages` | 助手与用户消息。 |
| `assistant_memory_items` | 助手长期记忆条目。 |
| `sleep_sessions` | 睡眠会话、状态、summary、feedback。 |
| `dream_entries` | 梦记正文、AI 分析、自动化处理标记。 |
| `sleep_capture_records` | 睡前 capture 记录，类型为 `dream` 或 `memo`。 |
| `notifications` | 通知中心条目。 |
| `dorms` | 宿舍主体、环境、规则设置、位置锚点。 |
| `dorm_members` | 宿舍成员状态、在线心跳、睡眠模式、徽章快照。 |
| `dorm_events` | 宿舍动态事件。 |
| `dorm_invites` | 宿舍邀请码与过期时间。 |
| `audio_tracks` | 音频目录缓存。 |
| `account_migrations` | 账号迁移或修复记录。 |

## Surface Id

卡片刷新和助手 patch 使用以下 `SurfaceId`：

| Surface | 说明 |
| --- | --- |
| `home_pre_sleep` | 睡前首页卡片与 pending banner。 |
| `sleep_mode` | 睡眠中页面卡片。 |
| `morning_feedback` | 晨间反馈结果页。 |
| `profile_report` | 我的页报告与趋势卡片。 |
| `assistant_context` | 助手上下文与记忆相关快照。 |

## Sleep Session

`sleep_sessions` 由睡眠入口、暂停、退出和晨间反馈共同维护。

| 字段/状态 | 当前语义 |
| --- | --- |
| `active` | 进入睡眠时为 true，暂停/退出/反馈后为 false。 |
| `sleepModeActive` | 与宿舍成员睡眠模式同步。 |
| `status: active` | 正在睡眠。 |
| `status: paused` | 暂停睡眠，尚未完成晨间反馈。 |
| `status: awaitingFeedback` | 已退出睡眠，等待晨间反馈。 |
| `status: completed` | 已完成反馈或明确完成。 |
| `summary` | 晨间反馈生成或用户提交的总结。 |
| `feedback` | 推荐反馈列表。 |
| `_automation` | app-api 或触发器派生处理的状态标记，用于避免重复处理。 |

## Dream Entry

`dream_entries` 保存梦境正文与 AI 分析。`/api/dream/save` 会写入或更新 entry，然后调用 `handleDreamEntryChange` 生成分析，并更新 `profile_report` 与 `assistant_context`。

不要在前端假设 dream 分析同步完成；接口响应中有 `analysis`，bootstrap 中也会回填最新持久化结果。

## Sleep Capture Record

`sleep_capture_records` 用于助手整理的睡前内容：

| 类型 | 说明 |
| --- | --- |
| `dream` | 梦记收纳，可进入梦记详情或梦记列表。 |
| `memo` | 事记/想法收纳，会进入想法仓库和助手上下文。 |

capture 流式接口会返回 `capture_record` event。非流式保存可使用 `/api/sleep-capture/save`。

## Assistant Thread and Message

助手线程以 `assistant_thread_summaries` 和 `assistant_messages` 分开保存。

- `assistant_thread_summaries` 维护标题、最近消息、当前 turn lease。
- `assistant_messages` 保存每条 user/assistant 消息，assistant 消息会带 `sourceMode`、`provider`、`model` 和 `errorMessage`。
- 同一线程流式回复会先获取 turn lease；没有拿到时返回 `THREAD_TURN_BUSY`，防止重复提交互相覆盖。

## Card Snapshot

`card_snapshots` 是后端物化的页面卡片，不是前端临时 UI 状态。它的写入来源包括：

- 夜间情绪选择后的 `prepareTonightPlanCallable`
- 睡眠会话状态变化
- 晨间反馈完成
- 梦记变化
- 助手 reply/capture 后台派生
- `/api/cards/refresh`

Flutter 页面应通过对应 repository/facade 读取快照，不应自行拼接后端集合路径。

## Dorm Model

宿舍数据拆为主体、成员、事件和邀请：

- `dorms`：宿舍名称、规则、环境、位置锚点。
- `dorm_members`：成员资料快照、状态、在线心跳、`sleepModeActive`、徽章字段。
- `dorm_events`：规则变更、提醒、加入离开等动态。
- `dorm_invites`：邀请码、创建者、过期时间。

成员心跳接口只更新 app 在线字段；睡眠模式由 `/api/sleep/*` 与成员状态接口维护，避免心跳覆盖睡眠状态。

## 序列化边界

- 后端 JSON 字段以 TypeScript 类型为准。
- Flutter 领域对象以 `lib/core/models/app_models.dart` 为准。
- JSON 到 Dart 的转换集中在 `lib/core/data/model_serializers.dart`。
- 新增字段时，先保证后端 bootstrap 可返回，再补 Dart serializer 的默认值和兼容逻辑。
