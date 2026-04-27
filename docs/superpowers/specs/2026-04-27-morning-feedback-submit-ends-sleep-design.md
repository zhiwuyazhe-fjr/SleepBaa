# 晨间反馈改为提交时结束睡眠设计

**日期**: 2026-04-27

## 目标

只调整 `HomePostSleepPage -> MorningFeedbackPage` 这条实时填写链路的语义，不改历史补填入口的业务定义。

本次目标：

1. 点击睡眠模式页里的“晨间反馈”时，先进入填写页，不立即结束睡眠模式。
2. 用户停留在填写页期间，这段睡眠继续累计。
3. 只有两种情况才真正结束本次睡眠：
   - 用户在反馈页点击提交
   - 用户在睡眠模式页明确选择“结束睡眠模式”
4. 用户填写到一半返回时，只是放弃这次填写，不触发“恢复睡眠模式”的额外加载流程。
5. 以最小必要改动完成，不顺手重做通知、日历、报告等既有补填入口。

## 约束

- 不改后端接口与数据模型。
- 不改 `SleepSessionStatus.awaitingFeedback` 对“已结束但未补反馈”的既有定义。
- 不新增反馈草稿持久化。
- 不新增新的页面或新的全局路由。
- 优先复用现有 `MorningFeedbackPage`、`SleepExperienceController` 和已有测试基建。

## 当前根因

当前实现把“进入晨间反馈页”定义成了“先结束睡眠，再进入补填页”，这与实时填写的用户心智相反。

现状关键点：

1. `HomePostSleepPage` 点击“晨间反馈”时会先 `await _finishSleepModeAndOpenFeedback(...)`。
2. `SleepExperienceController.finishSleepMode()` 会先取消睡眠通知、关闭活动 session，并把本日 session 转成 `awaitingFeedback`。
3. `MorningFeedbackPage` 当前只把 `awaitingFeedback && !sleepModeActive` 的 session 当成可提交对象。
4. 因为进入页面前就已经结束过睡眠，所以反馈页返回时才需要额外执行“恢复睡眠模式”。

这条链路带来的问题不是单纯“卡顿”，而是交互模型本身反了：

- 用户只是想先填反馈，却被系统提前判定为“已经结束睡眠”。
- 用户中途放弃填写时，系统还要再做一次恢复，产生额外等待和认知负担。

## 备选方案

### 方案 A：实时填写，提交时结束睡眠

这是推荐方案。

- 从睡眠模式页进入晨间反馈时，不结束 session。
- `MorningFeedbackPage` 允许承接当前 `active` session。
- 页面停留期间时长继续累计。
- 提交按钮负责“结束本次睡眠 + 提交反馈”。
- 反馈页返回时只放弃填写并返回上一页。

优点：

- 最符合用户心智。
- 不需要重做历史补填入口。
- 对现有模型改动最小，主要是翻转实时入口的时机。

代价：

- `MorningFeedbackPage` 需要同时支持 `active` 和 `awaitingFeedback` 两种来源。
- 提交动作要区分“先结束再提交”与“直接提交已结束 session”两条分支。

### 方案 B：进入反馈页时先冻结时长，提交时再正式结束

- 进入反馈页时将活动 session 暂停或临时封口。
- 用户提交后再真正落成 `awaitingFeedback/completed`。

不采用原因：

- 与本次已经确认的“停留在反馈页时继续累计”相冲突。
- 会引入额外的临时状态，改动比方案 A 更大。

### 方案 C：保持现有语义，只优化等待链路

- 仍然是先结束再进入反馈。
- 只把非关键副作用改成后台执行，减少卡顿。

不采用原因：

- 只能缓解“慢”，不能解决“反人类”的交互语义。
- 用户中途放弃后仍然要恢复睡眠模式，核心问题还在。

## 选定设计

采用方案 A：实时填写，提交时结束睡眠。

### 1. 入口语义

`HomePostSleepPage` 内的“晨间反馈”工具卡改为直接进入 `MorningFeedbackPage`，不再先调用 `finishSleepMode()`。

实现约束：

- 仍然传递当前 sleep-day session 的 `sessionId`。
- 不再从该入口写入 `resumeToSleep=1`。
- 当前“结束睡眠模式”按钮及其弹窗语义保持不变；用户如果明确走那条链路，仍然会先结束再进入补反馈流程。

这意味着：

- “晨间反馈”工具卡 = 实时填写入口
- “结束睡眠模式”按钮 = 显式结束入口

两个入口不再混用同一套业务语义。

### 2. 反馈页目标解析

`MorningFeedbackPage` 需要支持两类 session：

1. `active && sleepModeActive == true`
   - 来源：睡眠模式页里的实时填写入口
2. `awaitingFeedback && sleepModeActive == false`
   - 来源：通知、日历、睡眠报告等历史补填入口

解析规则：

- 显式 `sessionId` 优先。
- 当显式 `sessionId` 命中 `active` session 时，页面进入“实时填写模式”。
- 当显式 `sessionId` 命中 `awaitingFeedback` session 时，页面进入“历史补填模式”。
- 现有不带 `sessionId` 的通用晨间反馈路由继续沿用“寻找当前待补反馈 session”的逻辑，不扩大语义。

本次不新增新路由参数；页面模式通过命中的 session 当前状态直接推导。

### 3. 时长累计与页面展示

实时填写模式下，session 在反馈页停留期间继续保持 `active`。

行为要求：

- 反馈页摘要里的睡眠时长计算必须基于当前时刻，而不是基于进入页面那一刻的固定时间。
- 页面需要按与睡眠模式页一致的粗粒度节奏刷新时长展示，避免“实际上还在累计，但页面文案不动”。
- 如果用户在反馈页停留期间切回前台/后台，最终提交时仍以提交瞬间的 session 结束时刻为准。

本次不要求秒级实时刷新；与现有睡眠模式页一致的轻量刷新节奏即可。

### 4. 提交流程

反馈页主按钮在两种模式下语义不同：

- 实时填写模式：`提交反馈并结束本次睡眠`
- 历史补填模式：`提交反馈`

提交流程：

#### 实时填写模式

1. 读取最新 session 快照。
2. 关闭当前 active session，使其成为可提交的已结束 session。
3. 基于关闭后的 session 计算最终摘要与反馈数据。
4. 调用现有反馈提交流程。
5. 提交成功后回到首页并显示提交成功提示。

#### 历史补填模式

沿用现有“对已结束待反馈 session 直接提交”的逻辑，不额外插入结束步骤。

实现要求：

- “结束 session”与“提交反馈”必须串成一次用户可理解的单一操作。
- 若实时填写模式在结束 session 之后提交失败，页面应停留在反馈页并给出失败提示，不可无声返回。
- 一旦结束 session 已发生，后续失败只允许提示重试，不允许再做“自动恢复睡眠模式”补偿。

### 5. 返回行为

实时填写模式下，返回操作改为“放弃本次填写”而不是“恢复睡眠模式”。

行为要求：

- 点击返回键或系统返回时，实时填写模式统一弹出放弃确认，不再根据字段是否改动来决定。
- 用户确认后直接返回 `HomePostSleepPage`。
- 整个返回过程不调用 `resumeSleepModeFromFeedbackReturn()`。
- 不显示“正在返回睡眠模式”的加载页。

历史补填模式保持现状：

- 不引入新的“恢复睡眠模式”逻辑。
- 不扩大本次改动范围到所有历史补填返回行为。

### 6. 兼容与清理

- `resumeToSleep` 旧参数与相关兼容代码可暂时保留，避免影响已有深链或测试辅助路径。
- 但 `HomePostSleepPage` 不再生成这种参数。
- 与“返回后恢复睡眠模式”强绑定的交互文案、按钮文案和 loading 文案，需要只保留给兼容路径，不能继续出现在新的实时填写主路径上。

## 影响范围

- `lib/features/home/presentation/pages/home_post_sleep_page.dart`
- `lib/features/feedback/presentation/pages/morning_feedback_page.dart`
- `lib/core/state/sleep_experience_controller.dart`
- `lib/core/models/app_models.dart` 或相关 session 可提交判定辅助函数
- `test/widget_test.dart`
- `test/core/state/sleep_experience_controller_test.dart`
- `test/features/feedback/presentation/pages/morning_feedback_page_test.dart`

## 测试策略

至少补充或调整以下验证：

1. 从 `HomePostSleepPage` 点击“晨间反馈”后，会直接打开反馈页，且当前 session 仍然是 `active`。
2. 实时填写模式下返回确认后直接回到 `HomePostSleepPage`，过程中不会出现“恢复睡眠模式”的 loading。
3. 实时填写模式下提交后，session 会被结束并标记为已完成反馈。
4. 历史补填入口仍然可以对 `awaitingFeedback` session 正常提交，不受实时入口改造影响。
5. 通用晨间反馈路由仍然只处理待补反馈 session，不会错误吞入仍在进行中的活动 session。
6. 若实时填写模式在“结束后提交”阶段失败，页面停留当前页并给出错误提示。

## 非目标

- 不新增反馈草稿自动保存。
- 不统一重做通知、日历、睡眠报告入口的返回体验。
- 不改动“结束睡眠模式”按钮本身的业务定义。
- 不新增新的 session 状态枚举。
- 不处理更大范围的性能优化或动画重构。
