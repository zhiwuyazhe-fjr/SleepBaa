# Night Mood Welcome Guide

最后核验日期：2026-04-29。代码入口：`lib/features/night_mood/presentation/pages/night_welcome_gate_page.dart` 与 `lib/features/night_mood/presentation/widgets/night_mood_welcome_flow.dart`。

## 入口和展示条件

`/home/pre_sleep` 先进入 `NightWelcomeGatePage`。该 gate 监听：

- `settingsRepository`
- `nightWelcomeController`

当 `NightWelcomeController.shouldShowWelcome(...)` 返回 true 时展示 `NightMoodWelcomeFlow`；否则直接展示 `HomePreSleepPage`。

## 流程步骤

`NightMoodWelcomeFlow` 目前有 3 个步骤：

| Step | Widget | 说明 |
| --- | --- | --- |
| `select` | `_SelectionStep` | 选择心情，默认使用 `initialMood` 或 `NightMood.calm`。 |
| `reasons` | `_ReasonsStep` | 选择该心情的原因，可多选。 |
| `welcome` | `_WelcomeStep` | 展示基于 mood 的欢迎文案并完成流程。 |

可选心情来自 `NightMood.values`：

- `happy`
- `sad`
- `calm`

## 持久化行为

跳过欢迎：

1. 生成当前 evening period key。
2. 从鼓励语池选择一条 line。
3. 写 `EveningWelcomeLocalStore`。
4. 调 `nightWelcomeController` 标记本周期已处理。
5. 通过 `ProfileFacade.saveEveningEncouragement(...)` 保存。

完成欢迎：

1. 写入 mood、period key 和鼓励语。
2. `nightWelcomeController.setCompletedMood(mood)`。
3. `ProfileFacade.saveNightWelcomeSelection(...)` 持久化 mood 与鼓励语。

## 主题

欢迎流颜色由 `NightMoodPalette.fromMood(_selectedMood)` 生成。各步骤主要使用：

- `welcomeCardColor`
- `welcomeFaceColor`
- `welcomeAccentColor`
- `welcomeTextOnAccent`
- `welcomeSurfaceColor`

不要在欢迎流里直接写固定颜色；需要新 mood 时先扩 `NightMood` 与 `NightMoodPalette`。

## UI 约束

- 欢迎流是全屏流程，会临时替代首页内容。
- 底部操作区由 `_BottomActionBar` 管理，改按钮文案或数量时检查小屏高度。
- mood selector 使用 `MoodAvatar` 和 palette，不要改成静态图片。
- 文案来自 `NightMood` extension，新增文案应和 mood 枚举一起维护。

## 改动检查

- 改展示频率：检查 `NightWelcomeController.shouldShowWelcome` 和 `EveningWelcomeLocalStore`。
- 改保存字段：同步 `ProfileFacade`、settings serializer、CloudBase `/api/profile/save`。
- 改 mood 类型：同步 `NightMoodPalette`、欢迎流文案、序列化默认值。
