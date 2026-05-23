# 小眠 Agent 内部工具注册表

更新时间：2026-05-23

工具命名采用稳定前缀：`context.*`、`sleep.*`、`dorm.*`、`memory.*`、`cards.*`、`plan.*`、`capture.*`、`notification.*`、`navigation.*`、`audio.*`。

## 第一轮已接入工具

| Tool | 风险 | 是否需要硬确认 | 说明 |
| --- | --- | --- | --- |
| `context.read` | read | 否 | 读取助手上下文、宿舍、睡眠、梦记、长期记忆摘要 |
| `sleep.records.read` | read | 否 | 从上下文返回最近睡眠记录摘要 |
| `dream.records.read` | read | 否 | 从上下文返回最近梦记摘要 |
| `audio.catalog.read` | read | 否 | 读取睡眠音频目录 |
| `plan.generate_tonight` | low | 否 | 调用现有 TonightPlan 生成与卡片刷新链路 |
| `cards.refresh` | low | 否 | 按 surface 重新物化卡片快照 |
| `interference.save_tonight` | write | 否 | 写入今晚干扰因素快照 |
| `dorm.reminder.send` | write | 否 | 向可推断室友发送温和提醒；无目标时跳过 |
| `dorm.status.update` | write | 否 | 更新当前用户宿舍状态 |
| `dorm.rules.save` | write | 否 | 保存或提交宿舍公约设置 |
| `notification.write` | write | 否 | 写入站内通知 |
| `capture.save` | write | 否 | 保存梦记/事记 capture；缺少 session 时返回跳转建议 |
| `navigation.suggest` | read | 否 | 返回前端跳转建议 |
| `memory.upsert` | low | 否 | 写入长期记忆、行动效果或策略偏好 |

## 高风险保留策略

以下能力暂不允许 Agent 自动执行，必须前端硬确认后走专用接口：

- 账户删除、密码/登录方式变更、手机号解绑。
- 退出宿舍、解散宿舍、移除成员。
- 不可撤销的社交动作或可能造成明显打扰的批量提醒。
- 医疗诊断、心理治疗结论、药物建议。

## 审计要求

- 每次执行写 `agent_runs`。
- 每个计划写 `agent_plans`。
- 每个工具调用写 `agent_tool_calls`，包含输入、输出、状态、错误、耗时、undo payload 或补偿说明。
- 同步写 `assistant_runs`，保证旧排查链路仍可用。

## 第三轮审计接口状态

- `/api/agent/runs/:id` 已返回 `run`、`plan`、`toolCalls`，可用于排查完整执行链路。
- SSE 工具事件已带 `callId`、`undoable`、`committed`、`undoPayload`，前端可以将工具状态和后端审计记录对齐。
- 高风险动作仍不会自动执行；被跳过的工具会写 `agent_tool_calls` 并发出 `tool_failed`，错误原因为 `hard_confirm_required`。

## 第五轮新增工具

| Tool | 风险 | 是否需要硬确认 | 说明 |
| --- | --- | --- | --- |
| `sleep.mode.enter` | write | 否 | 创建或复用睡眠会话，并同步宿舍睡眠状态 |
| `sleep.mode.exit` | write | 否 | 退出睡眠模式，进入晨间反馈/报告刷新链路 |
| `audio.recommend` | read | 否 | 基于音频目录返回助眠音频建议和页面入口 |
| `report.profile.read` | read | 否 | 汇总最近睡眠、梦记和长期记忆，用于报告解读 |
| `dorm.invite.create` | write | 否 | 创建宿舍邀请码，供宿舍协同入口调用 |

## 第六轮运行时校验

- 每个工具执行前都会按 `inputSchema.properties` 和 `inputSchema.required` 做基础入参校验。
- 校验覆盖 `string`、`number`、`integer`、`boolean`、`array`、`object` 基础类型。
- 校验失败不会调用业务 handler，会写入 `agent_tool_calls`，并通过 SSE 发出 `tool_failed`。
- 失败错误统一以 `invalid_tool_input` 开头，便于排查 planner 生成异常或前端上下文传参异常。

## 第七轮补偿能力

- 新增 `/api/agent/tool-calls/:id/undo`，按工具调用 id 触发后端补偿。
- `agent_tool_calls` 新增 `undoStatus`、`undoAppliedAt`、`undoResult`、`undoError`，撤销结果回写原调用记录。
- 当前支持精确撤销：`interference.save_tonight`、`sleep.mode.exit`。
- 仅有补偿说明、无法精确恢复的工具调用返回 `AGENT_TOOL_UNDO_UNAVAILABLE`，并写入 unavailable 审计状态。

## 第十一轮前端结果动作

- `tool_completed` / `action_committed` 的工具输出可被 Flutter 解析为 `toolOutput`。
- `navigation.suggest` 输出 `{ route, label }` 时，前端会生成 `agent_navigation:*` 状态 token。
- 助手当前回复会把导航 token 渲染成跳转按钮，只接受 `/` 开头的 App 内路由。
- 该能力只消费已有工具输出，不提升工具风险等级，也不绕过高风险硬确认。
