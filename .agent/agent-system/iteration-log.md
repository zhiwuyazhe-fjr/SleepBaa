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
