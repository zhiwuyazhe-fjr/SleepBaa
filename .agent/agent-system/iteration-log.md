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

## 2026-05-23 第七轮

目标：补齐 Agent 自主执行后的补偿闭环，让已提交动作不只可审计，也能在可行时由后端执行精确撤销。

计划：

- [x] 扩展 `AgentToolCallDoc`，记录 `undoStatus`、`undoAppliedAt`、`undoResult`、`undoError`。
- [x] 仓库层新增 `getAgentToolCall`，可按 callId 拉取单次工具调用。
- [x] 新增 `undoAgentToolCall`，统一处理补偿逻辑和审计回写。
- [x] 新增 `/api/agent/tool-calls/:id/undo`，供前端撤销入口或排查工具调用。
- [x] 第一批支持精确撤销 `interference.save_tonight` 和 `sleep.mode.exit`；仅有补偿说明的动作返回 unavailable。
- [x] 增加 Agent API 集成测试，覆盖撤销成功和重复撤销幂等。
- [x] 跑 `npm --prefix functions run build`、`npm --prefix functions test` 与 `git diff --check`。

结果：

- 成功工具调用现在可以被后端重新定位，并把撤销结果写回原 `agent_tool_calls`。
- 今晚干扰因素可恢复到执行前快照；退出睡眠模式可恢复执行前的睡眠会话快照。
- 无法精确撤销的动作不会假装成功，会返回明确原因并写入 `undoStatus: unavailable`。

## 2026-05-23 第八轮

目标：把第七轮后端补偿能力接入 Flutter 助手页，让用户能在当前中枢回复下直接撤销可精确恢复的动作。

计划：

- [x] `AssistantReplyGateway` 新增 `undoToolCall`，CloudBase 实现调用 `/api/agent/tool-calls/:id/undo`。
- [x] 撤销成功后刷新 CloudBase snapshot store，拉取后端已重建的卡片快照。
- [x] `AssistantConversationController` 记录 `action_committed` 中可精确撤销的工具调用，并维护 available/running/applied/failed 状态 token。
- [x] 助手当前回复的工具状态列表增加撤销按钮，点击后调用 controller 并展示被动 toast。
- [x] 增加 Flutter 网关测试与 controller 测试，覆盖 undo endpoint 调用、撤销 token 暴露和幂等状态替换。
- [x] 跑 `flutter test test/core/backend/assistant_reply_gateway_test.dart`、`flutter test test/features/assistant/presentation/controllers/assistant_conversation_controller_test.dart`、`flutter test test/core/facades/app_facades_test.dart`。
- [ ] 全量 `flutter test test/widget_test.dart` 仍有既有失败，集中在旧助手入口 finder、宿舍状态、徽章、报告和睡眠模式断言，需单独清理。

结果：

- 当前助手回复能展示“可撤销一项动作”，并只对 `interference.save_tonight`、`sleep.mode.exit` 这类已支持精确撤销的动作开放按钮。
- 撤销中、撤销成功、撤销失败都会回写到当前消息的工具状态，避免重复点击时没有反馈。
- 前端撤销链路已经和第七轮后端审计/补偿 API 对齐。

## 2026-05-23 第九轮

目标：补齐长期记忆和自我进化的可观测入口，让中枢不只会写记忆，也能对外返回当前画像/策略权重概览。

计划：

- [x] 仓库层新增 `listAssistantMemoryItems`，支持按 query、kind、limit 检索，并可选择不刷新 `lastUsedAt`。
- [x] 新增 `buildAgentMemoryOverview`，按 kind 聚合长期记忆，提取 intervention effect、strategy weight 和冲突组摘要。
- [x] 新增 `/api/agent/memory`，返回 `totalCount`、`byKind`、`recent`、`interventionEffects`、`strategyWeights`、`contradictionGroups`。
- [x] recent 记忆通过 `compactMemoryItem` 输出排查字段，避免把内部完整文档无控制暴露给前端。
- [x] 增加后端单测和 app-api 集成测试，覆盖记忆概览聚合与 API 响应。
- [x] 跑 `npm --prefix functions run build`、`npm --prefix functions test` 与 `git diff --check`。

结果：

- 小眠的长期记忆现在有后端观测面，可用于后续“记忆中心”“自我进化报告”或排查页。
- 自我进化相关的有效/无效建议、策略权重和冲突证据可以被直接查询，不再只能从数据库集合里人工翻。

## 2026-05-23 第十轮

目标：把第九轮的长期记忆观测能力接入 Flutter 助手页，让用户和排查人员能从中枢入口直接查看“记忆与进化”概览。

计划：

- [x] `AssistantReplyGateway` 新增 `fetchMemoryOverview`，CloudBase 实现调用 `/api/agent/memory`。
- [x] 新增 Flutter 侧 `AssistantMemoryOverview`、kind summary、recent memory、effect summary 和 contradiction group 解析模型。
- [x] `AssistantConversationController` 新增记忆概览状态、加载状态、错误状态与 `refreshMemoryOverview`。
- [x] 助手页头部新增“记忆与进化”图标入口，打开后展示总量、画像分布、近期记忆、行动效果、策略权重和冲突证据。
- [x] 入口支持刷新和关闭；加载、空数据、错误状态都有明确 UI。
- [x] 增加 Flutter 网关测试与 controller 测试，覆盖 `/api/agent/memory` 调用与概览状态落地。
- [x] 跑 `flutter analyze` 目标文件、`flutter test test/core/backend/assistant_reply_gateway_test.dart`、`flutter test test/features/assistant/presentation/controllers/assistant_conversation_controller_test.dart`、`flutter test test/core/facades/app_facades_test.dart`、`flutter test test/widget_test.dart --name "assistant memory header opens memory overview sheet"` 与 `git diff --check`。

结果：

- 小眠助手页现在具备长期记忆/自我进化的前端观测入口，不再只依赖后端 API 或数据库人工排查。
- 记忆概览已经通过统一网关接入，后续可在“我的”“报告页”或调试页复用同一模型。
- 第十轮没有改变自动行动权限边界，只读取和展示记忆观测结果。

## 2026-05-23 第十一轮

目标：补齐 Agent 执行结果的“可行动入口”，让 `navigation.suggest` 不只显示状态文案，还能在助手回复里提供可点击跳转按钮。

计划：

- [x] `action_committed` SSE 事件补充 `output`，与 `tool_completed` 保持工具输出字段一致。
- [x] Flutter `AssistantStreamEvent` 新增 `toolOutput`，解析 `tool_completed` / `action_committed` 的工具输出。
- [x] `AssistantConversationController` 将 `navigation.suggest` 的 `{ route, label }` 输出转成稳定 `agent_navigation:*` surface token。
- [x] `AssistantToolStatus` 新增 `navigationRoute` / `navigationLabel`，并支持 `canNavigate`。
- [x] 助手当前回复的工具状态列表新增跳转按钮，点击后用 GoRouter 打开对应 App 路由。
- [x] 增加网关、controller 和 assistant surface 测试，覆盖工具输出解析、导航 token 暴露和 token 解码。
- [x] 跑 `npm --prefix functions run build`、`npm --prefix functions test`、目标文件 `flutter analyze`、相关 Flutter 测试、`flutter test test/widget_test.dart --name "assistant memory header opens memory overview sheet"` 与 `git diff --check`。

结果：

- Agent 现在能把“打开助眠音频”“继续写梦记”“需要你确认后再执行”等导航建议变成助手页内的行动按钮。
- 前端仍只接受 `/` 开头的 App 内路由，避免工具输出任意外链或无效路由直接进入跳转链路。
- 这轮不新增写入权限，只增强工具结果的可消费性。
