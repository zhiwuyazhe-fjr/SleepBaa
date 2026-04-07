# AI 编排说明

## 核心原则

- AI 助手是后端统一调度器，不是附属聊天框。
- 所有 AI 输出都必须先结构化，再写入数据库，再回填给前端。
- 客户端永远不直接接触原始模型输出。
- 没有真实模型时必须 fallback，不能阻塞 MVP。

## 输入来源

AI 每次编排固定拼这些上下文：

- `users`
- `user_settings`
- `user_state`
- `dorms`
- `dorm_members`
- `dorm_events`
- 最近 7 条 `sleep_sessions`
- 最近若干 `dream_entries`
- 当前线程 `assistant_messages`
- 当前触发事件类型

## 四条主链路

### 1. `prepareTonightPlan`

触发时机：

- 保存夜间心情
- 首次进入首页但没有今晚建议
- 手动刷新今晚建议

步骤：

1. 拉取用户、宿舍、睡眠、梦境、历史线程
2. 排序干扰因子
3. 生成 `TonightPlan`
4. 更新 `user_state`
5. 物化：
   - `home_pre_sleep`
   - `assistant_context`
6. 写 `assistant_runs`

输出：

- `coachSummary`
- `riskLevel`
- `topFactors[]`
- `recommendedActions[]`
- `updatedSurfaces[]`

### 2. `assistantReply`

触发时机：

- 用户在助手页发送 prompt

步骤：

1. 保证线程存在
2. 先写 user message
3. 读取完整 assistant context
4. `classifyIntent`
5. `generateStructuredReply`
6. 如有必要，刷新 `TonightPlan`
7. 写 `assistant_runs`
8. 写 assistant message
9. 刷新相关 snapshot

输出：

- `reply`
- `intent`
- `runId`
- `recommendedActions[]`
- `updatedSurfaces[]`

### 3. `onSleepSessionWrite`

触发时机：

- `sleep_sessions` 被创建或更新

关键分支：

- `active`
  - 进入 `sleep_mode`
  - 刷新 `sleep_mode`
- `awaitingFeedback`
  - 进入 `morning_feedback`
  - 写反馈提醒通知
  - 刷新 `morning_feedback`
- `completed`
  - 分析晨间反馈
  - 更新 `feedbackLoop`
  - 更新 `profileSummary`
  - 刷新：
    - `morning_feedback`
    - `profile_report`
    - `assistant_context`

### 4. `onDreamEntryWrite`

触发时机：

- 新增或覆盖 `dream_entries`

步骤：

1. 调 `summarizeDream`
2. 把结果写回 dream 文档的 `ai.*`
3. 更新 `profileSummary.dreamTrendSummary`
4. 刷新：
   - `profile_report`
   - `assistant_context`

## Provider 模式

### `deterministic`

- 默认模式
- 不依赖外部网络模型
- 适合 MVP 冒烟、联调、测试环境

### `external_http`

- 通过自定义 HTTP 接口接入第三方模型
- 配置：
  - `AI_PROVIDER_BASE_URL`
  - `AI_PROVIDER_API_KEY`
  - `AI_PROVIDER_MODEL`

### `cloudbase_ai`

- 使用 `@cloudbase/node-sdk` 的 CloudBase AI 能力
- 当前已预留模式切换和 JSON 结果归一化
- 建议模型：
  - `hunyuan-2.0-instruct-20251111`
  - 或按环境切换其他模型

## 当前已做的 AI 增强

- `classifyIntent` 统一收口
- 梦境分析结果固定结构化：
  - `summary`
  - `dominantEmotion`
  - `suggestedFocus`
  - `sourceRefs`
- 晨间反馈分析结果固定结构化：
  - `reviewSummary`
  - `effectiveActions`
  - `ineffectiveActions`
  - `profileSummary`
- `provider_factory.ts` 已支持：
  - fallback
  - 外部 HTTP provider
  - CloudBase AI provider

## 结构化输出校验

不管接哪个模型，最终都必须被 normalize：

- `StructuredAssistantReply`
- `TonightPlan`
- `DreamAnalysis`
- `MorningReviewResult`

如果模型输出不合规：

1. 先尝试抽取 JSON
2. 再按 schema 归一化
3. 不合法则回退 deterministic fallback

## 环境变量

### CloudBase 运行时

- `CLOUDBASE_ENV_ID`
- `CLOUDBASE_AUTH_BASE_URL`

### AI 相关

- `AI_PROVIDER_MODE=deterministic | external_http | cloudbase_ai`
- `AI_PROVIDER_NAME`
- `AI_PROVIDER_MODEL`
- `AI_PROVIDER_BASE_URL`
- `AI_PROVIDER_API_KEY`
- `AI_PROVIDER_TIMEOUT_MS`

## 给队员 C 的扩展入口

优先扩展：

- `functions/src/providers/provider_factory.ts`
- `functions/src/providers/ai_provider.ts`
- `functions/src/orchestrators/assistant_orchestrator.ts`

推荐继续做：

- 情绪趋势摘要
- 梦境标签更细粒度抽取
- 反馈总结更像真实陪伴式助手
- 推荐动作排序引入更多历史效果数据
