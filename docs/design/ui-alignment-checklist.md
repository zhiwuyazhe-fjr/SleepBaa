# UI Alignment Checklist

最后核验日期：2026-04-29。用于页面改版、走查和 PR 自检。

## 代码对齐

- 路由是否存在于 `lib/app/routes.dart`，页面路径是否已同步 [frontend/page-map.md](../frontend/page-map.md)。
- 页面是否通过 `context.appServices` 使用现有 facade/controller/repository。
- 是否复用了 `lib/core/widgets/**` 组件；功能私有组件是否留在对应 feature 下。
- 是否避免在页面里直接拼 CloudBase 路径或调用后端裸接口。

## Token 对齐

- 颜色来自 `AppColors` 或 `NightMoodPalette`。
- 间距来自 `AppSpacing`。
- 圆角来自 `AppRadius`。
- 页面 padding 使用 `AppPageInsets` 或和现有页面一致的 `EdgeInsets.fromLTRB(AppSpacing.xl, ...)`。
- 文本使用 `Theme.of(context).textTheme`，不要散落自定义字体族。

## 布局对齐

- 底部导航页面的滚动内容保留底部安全留白。
- 有全局助手 FAB 或 pending banner 的页面，避免主要 CTA 被覆盖。
- 卡片内部标题、说明、按钮层级清楚，不把页面级大标题塞进紧凑卡片。
- 文字在小屏、长中文、长英文、数字标签下不溢出。
- 横向列表或 chip 组在小屏可滚动或换行。

## 状态对齐

- loading、empty、error、permission denied 状态都能展示。
- 写操作后对应 repository/controller 会刷新或本地乐观更新。
- CloudBase 模式下 401/session refresh 不会让页面卡死。
- 助手流式状态包含 pending、streaming、complete、error。
- 通知已读后首页未读数和通知中心一致。

## 交互对齐

- 主要 CTA 一屏内可见，危险操作需要确认。
- 返回路径和 `context.go` / `context.push` 语义正确。
- 流式/耗时操作有不可重复提交保护。
- 页面级弹层使用 `AppModalSpec` 或现有 modal scaffold。
- 轻量成功/失败提示使用 `notifyPassiveToast`。

## 文档同步

- 新增页面：更新 [frontend/page-map.md](../frontend/page-map.md)。
- 改页面状态源：更新 [frontend/state-and-data-flow.md](../frontend/state-and-data-flow.md)。
- 改共享 token：更新 [design-system.md](design-system.md)。
- 改共享组件：更新 [components.md](components.md)。
- 改关键页面结构：更新对应 `page-guides/**`。
