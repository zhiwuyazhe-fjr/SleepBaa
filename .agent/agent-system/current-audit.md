# 小眠中枢 Agent 当前审计

更新时间：2026-05-23

## 已具备能力

- CloudBase `app-api` 已提供统一 HTTP Function 入口，支持认证、SSE、睡眠、宿舍、通知、卡片、助手对话等 App 内接口。
- `assistant_orchestrator` 已具备固定链路编排：普通回复、梦记/事记 capture、TonightPlan、梦境分析、晨间反馈分析、长期记忆写入、`assistant_runs` 记录和卡片刷新。
- Flutter 助手页已能解析 `ack`、`message_delta`、`message_completed`、`surface_patch`、`capture_record`、`memory_synced`、`done`、`error`。
- 仓库层已有多数业务写入口：睡眠会话、干扰因素、宿舍状态、宿舍提醒、公约、通知、卡片、长期记忆。

## 核心差距

- 助手仍以“对话 + 固定后处理”为主，不能显式拆解目标、选择工具、执行跨模块动作。
- 缺少 `agent_runs`、`agent_plans`、`agent_tool_calls` 级别的执行审计。
- 长期记忆只有基础条目，缺少证据、置信度衰减、冲突处理、行动效果和 agent run 归因。
- 前端没有展示计划和工具执行状态，用户只能看到最终回复。
- “自我进化”仍依赖固定画像刷新，没有把晨间反馈、建议有效性、宿舍事件转成可审计策略权重。

## 首轮改造目标

- 不引入独立 Agent 服务，直接在 `app-api` 内嵌 AgentRuntime。
- 新增内部 JSON tool registry，工具 schema 按 MCP 风格组织，后续可外露为 MCP。
- 新增 `/api/agent/run/stream`、`/api/agent/tools`、`/api/agent/runs/:id`。
- 普通助手流保持兼容；跨模块 prompt 可委托 AgentRuntime。
- 所有自动业务动作写入 `agent_tool_calls`，高风险动作必须硬确认或跳过。
- Flutter 助手页解析并展示规划、工具调用、记忆更新和完成事件。

## 首轮验收场景

- “我睡不着，室友很吵”：读取上下文，记录噪音干扰，生成今晚计划，尝试宿舍温和提醒，刷新卡片，写入行动记忆。
- “帮我规划今晚”：读取上下文，生成 TonightPlan，刷新 `home_pre_sleep` 与 `assistant_context`。
- “帮我写一份宿舍公约”：生成/保存低风险公约草案，写审计，返回可见状态。
- 普通问候仍能返回回复，不破坏旧助手流。

## 第四轮新增入口

- 首页睡前页、宿舍页、睡眠模式页、睡眠报告页已提供“让小眠处理/协同/解读”入口。
- 入口通过 `/assistant?agentPrompt=...&source=...&autoSubmit=1` 把当前页面状态带入 AgentRuntime。
- 这些入口仍走现有 `/api/agent/run/stream`，前端可继续展示规划、工具调用、记忆更新和完成状态。

## 后续轮次新增状态

- 第五轮后，工具覆盖已扩展到睡眠模式进入/退出、音频推荐、报告摘要和宿舍邀请。
- 第六轮后，所有工具执行前都会按 `inputSchema` 做基础入参校验，失败写入 `agent_tool_calls`。
- 第七轮后，`/api/agent/tool-calls/:id/undo` 支持对可精确恢复的工具调用执行补偿，并回写 undo 审计状态。
- 第八轮后，Flutter 助手页可展示可撤销动作，并调用后端 undo API。
- 第九轮后，`/api/agent/memory` 可返回长期记忆、自我进化策略权重和行动效果概览。
