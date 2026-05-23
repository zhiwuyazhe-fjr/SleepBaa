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
