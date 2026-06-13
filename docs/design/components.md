# Components

最后核验日期：2026-05-28。本文以 `lib/core/widgets/**` 当前文件为准。

## 基础容器

| Component | 文件 | 用途 |
| --- | --- | --- |
| `AppCard` | `lib/core/widgets/app_card.dart` | 默认白色卡片，带 padding、圆角和阴影。 |
| `AppStripCard` | `lib/core/widgets/app_strip_card.dart` | 横向条目卡片，可带 icon、标题、说明和 trailing。 |
| `AppMenuGroupCard` | `lib/core/widgets/app_menu_group_card.dart` | 设置/菜单型分组列表。 |
| `AppSettingsGroup` / `AppSettingsItem` | `lib/core/widgets/app_settings_group.dart` | 设置页分组、明细项。 |
| `IconBadge` | `lib/core/widgets/icon_badge.dart` | 小型 icon 容器或状态徽章。 |
| `StatusChip` | `lib/core/widgets/status_chip.dart` | 状态标签。 |

## 操作组件

| Component | 文件 | 用途 |
| --- | --- | --- |
| `PrimaryButton` | `lib/core/widgets/primary_button.dart` | 主按钮、ghost、outline、不同尺寸按钮。 |
| `QuickActionIconButton` | `lib/core/widgets/quick_action_icon_button.dart` | 首页快捷入口图标按钮。 |
| `AssistantFab` | `lib/core/widgets/assistant_fab.dart` | 全局助手悬浮入口。 |
| `AssistantFabDock` | `lib/core/widgets/assistant_fab_dock.dart` | 助手 FAB 与页面底部区域对齐。 |
| `BottomNavShell` | `lib/core/widgets/bottom_nav_shell.dart` | 三 Tab 底部导航壳层。 |

## 页面导航

| Component | 文件 | 用途 |
| --- | --- | --- |
| `AppDetailPageHeader` | `lib/core/widgets/app_detail_page_header.dart` | 二级页/详情页内嵌顶部返回标题行，统一左箭头、标题字号、字重、颜色和 8px 箭头标题间距，可带 trailing。 |
| `AppDetailPageAppBar` | `lib/core/widgets/app_detail_page_header.dart` | `Scaffold.appBar` 版本的详情页返回标题，适合普通浅色页面。 |

## 数据展示

| Component | 文件 | 用途 |
| --- | --- | --- |
| `HomeMetricCard` | `lib/core/widgets/home_metric_card.dart` | 首页干扰因素指标卡。 |
| `MetricTile` | `lib/core/widgets/metric_tile.dart` | 小型指标 tile。 |
| `MiniCalendarGrid` | `lib/core/widgets/mini_calendar_grid.dart` | 日历热力格。 |
| `SimpleBarChart` | `lib/core/widgets/simple_bar_chart.dart` | 简单柱状图。 |
| `SectionTitle` | `lib/core/widgets/section_title.dart` | 区块标题行。 |

## 头像与状态

| Component | 文件 | 用途 |
| --- | --- | --- |
| `UserAvatar` | `lib/core/widgets/user_avatar.dart` | 用户头像与在线状态。 |
| `MoodAvatar` | `lib/core/widgets/mood_avatar.dart` | 夜间情绪头像。 |
| `DormMemberAvatar` | `lib/features/dorm/presentation/widgets/dorm_member_avatar.dart` | 宿舍成员头像，属于 dorm 私有组件。 |

## 弹层

| Component | 文件 | 用途 |
| --- | --- | --- |
| `AppModalSpec` 系列 | `lib/core/widgets/modals/app_modal_spec.dart` | 弹窗、底部 sheet、选择器、表单规格。 |
| `AppCenterDialogScaffold` | `lib/core/widgets/modals/app_center_dialog.dart` | 中心弹窗框架。 |
| `AppBottomSheetScaffold` | `lib/core/widgets/modals/app_bottom_sheet.dart` | 底部 sheet 框架。 |
| `AppModal` helpers | `lib/core/widgets/modals/app_modal.dart` | 根据 spec 展示对应 modal。 |

## 反馈组件

| Component | 文件 | 用途 |
| --- | --- | --- |
| `PassiveToast` | `lib/core/widgets/passive_toast.dart` | App 内轻量提示。 |
| `PlaceholderPageScaffold` | `lib/core/widgets/placeholder_page_scaffold.dart` | 未完成页面或整理中状态。 |

## 首页私有组件

| Component | 文件 | 用途 |
| --- | --- | --- |
| `HomeHeroPair` | `lib/features/home/presentation/widgets/home_hero_pair.dart` | 首页顶部两个主卡片布局。 |
| `SleepRiskCard` | `lib/features/home/presentation/widgets/home_widgets.dart` | 睡眠风险/今晚概况卡。 |
| `StartSleepModeCard` | `lib/features/home/presentation/widgets/home_widgets.dart` | 进入睡眠模式卡片。 |
| `HomeActionCard` | `lib/features/home/presentation/widgets/home_widgets.dart` | 推荐卡片，支持音频状态。 |
| `SleepModeMoon` | `lib/features/home/presentation/widgets/home_widgets.dart` | 睡眠模式月亮动效。 |
| `HomeQuickActionDefinition` | `lib/features/home/presentation/widgets/home_quick_actions.dart` | 首页快捷入口配置。 |

## 使用边界

- 全局组件放 `core/widgets`，功能私有组件放 `features/<feature>/presentation/widgets`。
- 组件 props 应接收领域对象或简单展示字段，不要在组件内部直接访问 CloudBase。
- 可复用的弹窗优先用 `AppModalSpec`，不要每页复制一套 `showDialog` 样式。
- 页面中出现第三个相似卡片时，优先抽成私有组件；跨 feature 复用时再提升到 `core/widgets`。
- 新组件必须使用 `AppSpacing`、`AppRadius` 和 `Theme.of(context).textTheme`。
- 二级页/详情页的左上角返回箭头 + 标题必须优先使用 `AppDetailPageHeader` 或 `AppDetailPageAppBar`；深色页面通过 `foregroundColor` 指定前景色，不要再复制私有 `IconButton + Text` 组合。
