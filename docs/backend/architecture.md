# 后端架构说明

## 1. 架构目标

本项目后端不是单独提供一个聊天模块，而是把 AI 助手设计成统一编排器：

用户输入心情和干扰因子 -> 生成今晚建议 -> 进入睡眠模式 -> 记录梦境 -> 提交晨间反馈 -> 更新画像 -> 刷新前端卡片。

要求：

- 不改现有页面布局
- Flutter 页面只通过 facade / repository 取数
- 所有 AI 相关推理都放云端

## 2. 当前分层

### 2.1 Flutter 客户端

- `lib/features/**/presentation`
  - 页面层，尽量不动
- `lib/core/facades/**`
  - 对页面暴露稳定方法
- `lib/core/data/**`
  - CloudBase repository 实现
- `lib/core/backend/**`
  - CloudBase Auth HTTP、App API Client、Session Store、Snapshot Store

### 2.2 CloudBase 云端

- `functions/app-api`
  - 唯一对客户端暴露的 HTTP Function
- `functions/on-sleep-session-write`
  - `sleep_sessions` 触发器函数
- `functions/on-dream-entry-write`
  - `dream_entries` 触发器函数
- `functions/src/orchestrators/**`
  - AI 主编排逻辑
- `functions/src/repositories/**`
  - NoSQL 读写与聚合
- `functions/src/providers/**`
  - AI provider 选择器与 fallback
- `functions/src/services/**`
  - 卡片物化、因子排序等服务

## 3. 当前主链路

### 3.1 今晚建议链路

1. 用户保存夜间心情
2. Flutter 调 `POST /api/profile/night-mood`
3. 后端读取：
   - `users`
   - `user_settings`
   - `user_state`
   - `sleep_sessions`
   - `dream_entries`
   - `dorms` / `dorm_members` / `dorm_events`
4. AI provider 生成 `tonightPlan`
5. 写回 `user_state`
6. 物化 `card_snapshots/home_pre_sleep`
7. 前端 repository 自动把推荐映射回现有 `NightRecommendation`

### 3.2 睡眠闭环链路

1. 用户进入睡眠模式
2. Flutter 调 `POST /api/sleep/enter`
3. 写入 `sleep_sessions`
4. 同步编排生成 `sleep_mode` 快照
5. 用户记录梦境，调用 `POST /api/dream/save`
6. 梦境分析回写 `profileSummary`
7. 用户晨间反馈，调用 `POST /api/feedback/morning`
8. 后端更新 `feedbackLoop`
9. 刷新 `morning_feedback`、`profile_report`、`assistant_context`

### 3.3 Assistant 对话链路

1. Flutter 调 `POST /api/assistant/reply`
2. 后端执行：
   - `buildAssistantContext`
   - `classifyIntent`
   - `generateStructuredReply`
   - 必要时刷新 `tonightPlan`
3. 返回：
   - `reply`
   - `runId`
   - `intent`
   - `recommendedActions[]`
   - `updatedSurfaces[]`

## 4. 当前核心集合

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

关键主键约定：

- `user_state._id = uid`
- `card_snapshots._id = ${uid}:${surfaceId}`
- `dorm_members._id = ${dormId}:${uid}`
- `assistant_messages._id = ${threadId}:${messageId}`

## 5. AI 助手的后端职责

AI 助手负责的不是“回复一句话”，而是：

- 汇总用户长期画像
- 识别当前夜晚风险点
- 生成今晚行动建议
- 对梦境做结构化摘要
- 对晨间反馈做有效性归因
- 更新 `user_state.profileSummary`
- 驱动 `card_snapshots` 刷新

## 6. 前端为什么可以不改 UI

因为当前已经把后端结果收束到现有数据层：

- `RecommendationRepository`
  - 优先读取 `user_state.tonightPlan.recommendedActions`
- `InsightsRepository`
  - 优先读取 `card_snapshots/profile_report`
  - 优先读取 `card_snapshots/home_pre_sleep`
- `DormFacade`
  - 走 CloudBase BFF
- `ProfileFacade`
  - 走 CloudBase Auth + App API

也就是说：

- 页面结构不变
- 只替换数据来源
- 无数据时仍保留本地 fallback

## 7. 自动触发策略

当前是“双轨兜底”：

### 7.1 同步路径

这些接口写库后会立即同步做后处理：

- `/api/profile/night-mood`
- `/api/sleep/enter`
- `/api/sleep/exit`
- `/api/dream/save`
- `/api/feedback/morning`
- `/api/assistant/reply`

### 7.2 数据库触发器兜底

集合触发器：

- `sleep_sessions` -> `on-sleep-session-write`
- `dream_entries` -> `on-dream-entry-write`

作用：

- 控制台手改数据时仍能自动补后处理
- 避免只依赖客户端入口

## 8. 当前 MVP 范围

已进入 MVP 主线的能力：

- 匿名登录
- 手机号绑定到资料
- 今晚建议生成
- 睡眠模式进入/退出
- 梦境记录与分析
- 晨间反馈回写
- 宿舍创建/加入/邀请
- Assistant 对话与卡片刷新

暂不进入本轮的能力：

- 账号体系升级与合并
- MySQL 分析库
- 新页面重构
- 扩展触发器到更多集合
