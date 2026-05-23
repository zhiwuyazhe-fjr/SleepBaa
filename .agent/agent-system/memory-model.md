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

## 自我进化边界

- 不做代码自修改。
- 只更新可审计的画像、偏好、策略权重和行动效果。
- 高风险动作仍需要硬确认。
- 不输出医疗诊断或治疗结论。

