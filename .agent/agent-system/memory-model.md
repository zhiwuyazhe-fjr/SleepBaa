# 小眠长期记忆与自我进化模型

更新时间：2026-05-23

## 记忆字段

`assistant_memory_items` 在原有 `kind`、`content`、`canonicalKey`、`keywords`、`confidence`、`salience` 基础上扩展：

- `decayScore`：随时间衰减后的有效分。
- `evidenceRefs`：来源证据，如 `agent_runs:<id>`、`tool:<name>`、`assistant_messages:<id>`。
- `contradictionGroup`：冲突归并组，同组新证据可覆盖旧偏好。
- `sourceActionId`：产生该记忆的行动或工具调用 id。
- `sourceAgentRunId`：产生该记忆的 agent run id。
- `effectivenessScore`：行动有效性分，晨间反馈与用户拒绝会调整。
- `lastUsedAt`：被检索或用于规划的时间。

## 记忆类型

- `profile`：长期画像事实。
- `preference`：用户偏好与禁忌。
- `sleep_pattern`：作息和睡眠规律。
- `dorm_context`：宿舍环境、室友协同模式。
- `intervention_effect`：某类建议的有效/无效证据。
- `agent_action`：Agent 已执行动作和用户反应。
- `strategy_weight`：策略权重，如噪音优先、音频降权、沟通升权。

## 合并与冲突

- 同一 `canonicalKey` 直接 upsert。
- 同一 `contradictionGroup` 内，新证据置信度更高时覆盖旧偏好；低置信度只追加证据。
- 多次有效建议升高 `effectivenessScore` 与 `salience`。
- 多次无效或被拒绝建议降低 `effectivenessScore`，后续 planner 减少选择。

## 第二轮落地状态

- reply insight、legacy memory、morning feedback 都会补齐 `decayScore`、`evidenceRefs`、`contradictionGroup`、`sourceAgentRunId` 等扩展字段。
- 晨间反馈会把有效建议写成 `intervention_effect` 正向证据，把无效建议写成负向证据，并生成 `strategy_weight` 摘要。
- 记忆检索排序已使用衰减分、置信度和行动有效性分；被选中的记忆会刷新 `lastUsedAt`。
- TonightPlan 的行动排序已读取 `intervention_effect` / `strategy_weight`，让有效行动升权、无效行动降权。

## 第九轮观测入口

- `/api/agent/memory` 返回长期记忆概览，不执行写入型业务动作。
- 输出包含 `byKind`、`recent`、`interventionEffects`、`strategyWeights` 和 `contradictionGroups`。
- 排查读取时 `touchLastUsed: false`，避免单纯打开观测页改变记忆使用时间。
- `recent` 使用 compact 形态，只输出 id、kind、content、confidence、salience、decay、effectiveness、evidence refs、source ids 和更新时间。

## 第十轮前端入口

- Flutter `AssistantReplyGateway.fetchMemoryOverview` 已对齐 `/api/agent/memory` 响应结构。
- `AssistantConversationController` 维护记忆概览、加载状态和错误状态，避免 UI 直接散落调用后端。
- 助手页“记忆与进化”入口展示总量、画像分布、近期记忆、行动效果、策略权重和冲突证据。
- 前端入口仅做观测读取，不触发 `memory.upsert`，也不改变自动行动权限边界。

## 第十二轮执行结果反哺

- `AgentToolCallDoc.committed` 记录工具是否真正提交了业务动作，避免把只读成功或返回 skipped 的工具误当作执行成功。
- Agent run 结束后会合成 `agent_action` 记忆，记录本轮已提交动作、跳过动作和失败动作，证据引用 `agent_runs:<id>` 与 `agent_tool_calls:<id>`。
- 可映射到行动目录的工具会生成 `strategy_weight` 弱信号，例如宿舍状态/提醒映射到 `dorm-quiet`，capture 映射到 `thought-clean`。
- 工具成功提交只写入小幅正向策略权重；工具失败、缺参或返回 skipped 写入小幅负向权重；晨间反馈仍是更强的 `intervention_effect` 证据。
- 用户执行 undo 后会写入 `agent_action:undo:*` 与对应负向 `strategy_weight`，表示该动作刚被用户撤回，后续规划应谨慎重复。

## 自我进化边界

- 不做代码自修改。
- 只更新可审计的画像、偏好、策略权重和行动效果。
- 高风险动作仍需要硬确认。
- 不输出医疗诊断或治疗结论。
