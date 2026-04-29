# Design System

最后核验日期：2026-04-29。本文以 `lib/app/theme/**` 与共享组件实际使用为准。

## 设计原则

- 先使用 `AppColors`、`AppSpacing`、`AppRadius`、`AppTextStyles`，不要在页面里散落新的 magic number。
- 页面背景、卡片、按钮、toast、sheet、dialog 使用共享组件已有 token。
- 功能页可以有局部氛围，但底层导航、设置、列表、表单保持清晰、紧凑、可扫读。
- 新增视觉 token 必须放在 `lib/app/theme/**`，并同步本文件。

## 颜色

主色来自 `lib/app/theme/app_colors.dart`。

| Token | 值 | 用途 |
| --- | --- | --- |
| `background` | `#F9F9FB` | App 默认背景。 |
| `surface` | `#FFFFFF` | 卡片和主要容器。 |
| `surfaceMuted` | `#F2F4F6` | 次级容器和图表背景。 |
| `surfaceSoft` | `#ECEEF1` | 低强调块。 |
| `surfaceBorder` | `#DFE3E7` | 控件边框。 |
| `divider` | `#EBEEF2` | 分割线。 |
| `textPrimary` | `#2F3336` | 正文主文字。 |
| `textSecondary` | `#5B6063` | 次级文字。 |
| `textHint` | `#A0A0A0` | 弱提示。 |
| `primary` | `#00697A` | 主品牌色。 |
| `primarySoft` | `#8EDDF2` | 柔和主色。 |
| `primaryHighlight` | `#B2EBF2` | 高亮背景。 |
| `primaryDeep` | `#004F5D` | 深色主色。 |
| `calmBlue` | `#4EA8C2` | 睡眠/平静辅助色。 |
| `success` | `#4F8B6F` | 成功状态。 |
| `warning` | `#AD7A36` | 警告状态。 |

深色和悬浮层：

| Token | 值 | 用途 |
| --- | --- | --- |
| `darkBackground` | `#0C0E10` | 深色整屏背景。 |
| `darkCard` | `#0B192E` | 深色卡片。 |
| `darkSurface` | `#1A1C1E` | 深色弹窗表面。 |
| `darkPill` | `#1A1A1A` | 选中底部导航 pill。 |
| `onDark` | `#F9F9FB` | 深底文字。 |

## 夜间情绪主题

`NightMoodPalette.fromMood` 根据 `NightMood` 生成主题扩展：

| Mood | 主题方向 | 主要用途 |
| --- | --- | --- |
| `happy` | 粉色系 | 开心状态欢迎流。 |
| `sad` | 暖橙系 | 低落状态欢迎流。 |
| `calm` | 绿色系 | 平静状态欢迎流。 |
| `null` | 默认蓝绿色 | 未选择状态和通用睡前视觉。 |

页面中需要情绪主题时使用：

```dart
final NightMoodPalette palette = context.nightMoodPalette;
```

或在明确 mood 时使用：

```dart
final NightMoodPalette palette = NightMoodPalette.fromMood(mood);
```

## 间距

来自 `AppSpacing`：

| Token | 值 |
| --- | --- |
| `xxs` | 4 |
| `xs` | 8 |
| `sm` | 12 |
| `md` | 16 |
| `lg` | 20 |
| `xl` | 24 |
| `xxl` | 32 |
| `xxxl` | 40 |

页面默认横向边距使用 `AppPageInsets.horizontal = AppSpacing.xl`。底部导航页面注意保留 88 到 120 的底部滚动留白。

## 圆角

来自 `AppRadius`：

| Token | 值 | 用途 |
| --- | --- | --- |
| `xs` | 8 | 小型图块。 |
| `sm` | 16 | 按钮、toast、二级表面。 |
| `standard` | 20 | 控件和紧凑卡片。 |
| `md` | 24 | 普通卡片、strip card。 |
| `lg` | 32 | 大卡片。 |
| `xl` | 48 | pill、sheet 顶部。 |

默认组件映射：

- `AppRadius.card` -> 24
- `AppRadius.cardLarge` -> 32
- `AppRadius.button` -> 16
- `AppRadius.control` -> 20
- `AppRadius.pill` -> 48

## 字体

`AppTextStyles.buildTextTheme()` 定义全局 `TextTheme`：

| Style | Size | Weight | 用途 |
| --- | --- | --- | --- |
| `displayLarge` | 40 | 800 | 少量主视觉标题。 |
| `displayMedium` | 32 | 800 | 大段落主标题。 |
| `headlineLarge` | 28 | 800 | 页面标题。 |
| `headlineMedium` | 24 | 800 | 区块标题。 |
| `headlineSmall` | 20 | 700 | 卡片标题。 |
| `titleLarge` | 18 | 700 | 列表/分组标题。 |
| `titleMedium` | 16 | 700 | 控件标题。 |
| `bodyLarge` | 16 | 500 | 正文。 |
| `bodyMedium` | 14 | 500 | 常规文本。 |
| `bodySmall` | 12 | 500 | 辅助信息。 |
| `labelLarge` | 14 | 700 | 主要标签。 |
| `labelMedium` | 12 | 700 | 次级标签。 |
| `labelSmall` | 10 | 700 | 极小标签。 |

CJK fallback 在 `AppTextStyles.cjkFallbackFonts` 中统一维护。

## 阴影

`AppColors.cardShadow` 用于默认白色卡片；`AppColors.floatingShadow` 用于更高层级的悬浮块或弹层。不要在页面里复制 box shadow 数组，除非确实需要功能私有表现。

## 页面 Insets

| API | 用途 |
| --- | --- |
| `AppPageInsets.page()` | 普通页面滚动内容。 |
| `AppPageInsets.floatingPage()` | 有底部导航或悬浮按钮的页面。 |

## 新增规范

新增 token 前先确认：

1. 是否可以用现有 `AppSpacing` / `AppRadius` 组合。
2. 是否已有共享组件能承载这个样式。
3. 是否会影响多页面一致性。
4. 是否需要同步 `docs/design/components.md` 或页面指南。
