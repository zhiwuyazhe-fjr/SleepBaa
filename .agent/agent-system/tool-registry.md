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

