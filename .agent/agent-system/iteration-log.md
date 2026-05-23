# 小眠 Agent 迭代日志

## 2026-05-23 第一轮

目标：把小眠从固定助手链路升级为内嵌中枢 AgentRuntime。

计划：

- [x] 建立 `.agent/agent-system` 迭代记忆区。
- [x] 新增 Agent 类型、工具注册表、运行时和审计落库。
- [x] 新增 `/api/agent/run/stream`、`/api/agent/tools`、`/api/agent/runs/:id`。
- [x] Flutter 解析 Agent SSE 事件并展示工具状态。
- [x] 增加后端与 Flutter 回归测试。
- [x] 跑 `npm --prefix functions test` 与助手相关 Flutter 测试。
- [ ] 全量 `flutter test` 仍有既有 UI/状态断言失败，需要单独清理。

结果：

- 后端新增 `AgentRuntime`、内部 JSON tool registry、`agent_runs`、`agent_plans`、`agent_tool_calls`。
- `/api/assistant/reply/stream` 在跨模块 prompt 下可委托 AgentRuntime；`agentRuntime: "off"` 可保留旧链路。
- Flutter 端 `CloudBaseAssistantReplyGateway` 改为优先走 `/api/agent/run/stream`，并解析 planning/tool/memory/agent done 事件。
- 已通过 `npm --prefix functions test`。
- 已通过 `flutter test test\core\backend\assistant_reply_gateway_test.dart test\features\assistant\presentation\controllers\assistant_conversation_controller_test.dart`。

## 2026-05-23 第二轮

目标：把长期记忆从事实存档升级为可审计、可检索、可反向影响今晚建议的自我进化闭环。

计划：

- [x] 抽出 `assistant_memory_governance`，统一生成扩展记忆字段。
- [x] 晨间反馈完成后写入 `intervention_effect` 与 `strategy_weight` 记忆。
- [x] 记忆检索加入 `decayScore`、`confidence`、`effectivenessScore` 评分，并回写 `lastUsedAt`。
- [x] TonightPlan 推荐排序读取有效/无效干预记忆，自动升权或降权建议。
- [x] `morning_feedback_analysis` 写入 `assistant_runs`，保留兼容排查链路。
- [x] 增加后端测试覆盖晨间反馈记忆落库与行动排序影响。
- [x] 跑 `npm --prefix functions run build`、`git diff --check`、`npm --prefix functions test`。

结果：

- `assistant_memory_items` 新增字段开始在 reply insight、旧链路记忆、晨间反馈记忆中稳定填充。
- 晨间反馈中的有效建议会形成 `effectivenessScore: 1`，无效建议会形成 `effectivenessScore: -1`。
- 后续 `pickRecommendedActions` 会根据长期记忆调整 TonightPlan 推荐顺序。
- 后端函数测试 82 项通过。

## 2026-05-23 第三轮

目标：补齐 Agent 自主执行后的审计详情和前端可消费的工具执行元数据，为后续结果卡、撤销入口和排查页做基础。

计划：

- [x] `/api/agent/runs/:id` 从只返回 run 扩展为返回 `run`、`plan`、`toolCalls`。
- [x] 仓库层增加 `getAgentPlan` 与 `listAgentToolCalls`，按 runId 拉取完整执行链路。
- [x] SSE 的 `tool_started`、`tool_completed`、`tool_failed`、`action_committed`、`memory_updated` 带上 `callId` 等审计元数据。
- [x] `tool_completed` 与 `action_committed` 输出 `committed`、`undoable`、`undoPayload`，让前端可以识别可补偿动作。
- [x] Flutter `AssistantStreamEvent` 解析 `toolCallId`、`undoable`、`committed`、`undoPayload`。
- [x] 增加后端 API 测试与 Flutter 网关解析测试。
- [x] 跑 `npm --prefix functions run build`、`npm --prefix functions test`、助手相关 Flutter 测试、`git diff --check`。

结果：

- Agent run 详情接口可以一次取回计划步骤和工具调用审计，不再只能看到 run 摘要。
- 前端流式事件已经保留工具调用 id 与撤销/补偿载荷，后续可直接渲染结果卡或撤销入口。
- 后端函数测试 82 项通过。
- 已通过 `flutter test test\core\backend\assistant_reply_gateway_test.dart test\features\assistant\presentation\controllers\assistant_conversation_controller_test.dart`。

## 2026-05-23 第四轮

目标：把小眠从“助手页里的对话能力”推进为 App 各核心页面可调用的中枢入口。

计划：

- [x] 新增 `AppRoutes.assistantAgentLocation`，支持携带 `agentPrompt`、`source` 和自动提交参数。
- [x] `AssistantPage` 支持读取初始 agent prompt，并在页面打开后自动提交给中枢运行时。
- [x] 新增通用 `AssistantAgentEntryButton`，用于页面内“让小眠处理”入口。
- [x] 首页睡前页接入“让小眠规划今晚”，携带噪音、干扰因素和候选建议上下文。
- [x] 宿舍页接入“小眠协同”，携带宿舍噪音、安静评级和室友数量上下文。
- [x] 睡眠模式页接入“让小眠处理”，携带活跃睡眠会话和宿舍状态上下文。
- [x] 睡眠报告页接入“让小眠解读报告”，携带报告指标、最近记录和待反馈数量。
- [x] 跑 `flutter test test\app\routes_test.dart`、助手相关 Flutter 测试、`flutter test test\features\dorm\presentation\pages\dorm_page_hub_card_test.dart`、`git diff --check`。

结果：

- 首页、宿舍、睡眠模式、报告页都可以直接唤起小眠中枢，并把页面状态转成结构化 prompt。
- 助手页支持 deep link 自动提交，用户点击入口后不需要手动复制上下文。
- 新入口仍复用现有助手 SSE、工具状态流和 AgentRuntime 审计链路。

## 2026-05-23 第五轮

目标：扩大 Agent 工具覆盖面，让中枢能直接触达更多 App 模块，而不是只处理今晚规划和宿舍提醒。

计划：

- [x] 新增 `sleep.mode.enter`，支持 Agent 创建/复用睡眠会话并同步宿舍睡眠状态。
- [x] 新增 `sleep.mode.exit`，支持 Agent 退出睡眠模式并触发晨间反馈/报告刷新链路。
- [x] 新增 `audio.recommend`，读取音频目录并返回助眠音频建议入口。
- [x] 新增 `report.profile.read`，读取最近睡眠、梦记和长期记忆形成报告摘要。
- [x] 新增 `dorm.invite.create`，支持 Agent 创建宿舍邀请。
- [x] planner 增加睡眠模式、报告复盘、音频支持、宿舍邀请等意图路由。
- [x] 增加工具注册表与睡眠模式进入链路测试。
- [x] 跑 `npm --prefix functions run build` 与 `npm --prefix functions test`。

结果：

- Agent 工具注册表覆盖睡眠模式、音频、报告、宿舍邀请等更多 App 模块。
- “开始睡眠模式”“退出睡眠”“解读报告”“推荐助眠音频”“邀请室友”等 prompt 能进入专门计划分支。
- 后端函数测试 83 项通过。

## 2026-05-23 第六轮

目标：强化 Agent 工具执行前的入参校验，避免 planner 或前端上下文生成异常时把错误数据写入业务模块。

计划：

- [x] 新增 `validateAgentToolInput`，按工具 `inputSchema` 检查 required 字段和基础类型。
- [x] 在工具执行前加入统一校验，失败时不调用业务 handler。
- [x] 校验失败写入 `agent_tool_calls`，状态为 `failed`，错误原因以 `invalid_tool_input` 开头。
- [x] 校验失败通过 SSE 发出 `tool_failed`，保留 `callId`、`toolName`、`risk`、`undoable` 等排查字段。
- [x] 增加后端测试覆盖 schema 类型不匹配场景。
- [x] 跑 `npm --prefix functions run build`、`npm --prefix functions test` 与 `git diff --check`。

结果：

- AgentRuntime 对所有已注册工具执行统一 schema 守门，不再只依赖工具 handler 内部容错。
- 无效工具输入会形成完整审计链路，前端也能收到明确失败事件。
- 后续扩展工具时，只要补齐 `inputSchema`，即可自动获得基础校验能力。
