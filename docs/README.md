# Docs 总入口

最后核验日期：2026-04-29。本目录以当前代码为唯一事实来源。

## 文档放置原则

| 位置 | 收纳内容 | 代表文档 |
| --- | --- | --- |
| `backend/**` | 后端架构、接口、数据模型、CloudBase 联调、部署和 AI runtime。 | [backend/cloudbase-team-manual.md](backend/cloudbase-team-manual.md), [backend/cloudbase-operations.md](backend/cloudbase-operations.md) |
| `frontend/**` | Flutter 目录、路由、页面状态、数据流和通知。 | [frontend/overview.md](frontend/overview.md), [frontend/page-map.md](frontend/page-map.md) |
| `design/**` | 设计系统、共享组件、页面 UI 指南和验收清单。 | [design/design-system.md](design/design-system.md), [design/components.md](design/components.md) |
| `templates/**` | 可复用的 Markdown 模板。GitHub 实际生效表单仍以 `.github/ISSUE_TEMPLATE/**` 为准。 | [templates/issue_bug_template.md](templates/issue_bug_template.md), [templates/issue_feature_template.md](templates/issue_feature_template.md) |
| `docs/` 根目录 | 总入口和确认为历史/冻结的文档。 | [README.md](README.md) |

## 建议阅读顺序

| 场景 | 推荐文档 |
| --- | --- |
| 了解整体架构 | [backend/architecture.md](backend/architecture.md), [frontend/overview.md](frontend/overview.md) |
| 新成员做 CloudBase 联调 | [backend/cloudbase-team-manual.md](backend/cloudbase-team-manual.md) |
| 查后端接口 | [backend/api-reference.md](backend/api-reference.md) |
| 查集合、模型、快照 | [backend/data-model.md](backend/data-model.md) |
| 查 AI 助手运行链路 | [backend/assistant-runtime.md](backend/assistant-runtime.md) |
| 做部署、脚本或运维排查 | [backend/cloudbase-operations.md](backend/cloudbase-operations.md) |
| 查页面、路由、文件 | [frontend/page-map.md](frontend/page-map.md) |
| 查页面状态和数据流 | [frontend/state-and-data-flow.md](frontend/state-and-data-flow.md) |
| 做 UI 或视觉调整 | [design/design-system.md](design/design-system.md), [design/components.md](design/components.md), [design/ui-alignment-checklist.md](design/ui-alignment-checklist.md) |

## 后端与 CloudBase

- [backend/architecture.md](backend/architecture.md)：Flutter 到 CloudBase 的后端分层。
- [backend/api-reference.md](backend/api-reference.md)：`app-api` 当前 HTTP 与 SSE 路由。
- [backend/data-model.md](backend/data-model.md)：CloudBase collection、bootstrap payload、surface、关键模型。
- [backend/assistant-runtime.md](backend/assistant-runtime.md)：助手上下文、流式事件、记忆、provider。
- [backend/cloudbase-team-manual.md](backend/cloudbase-team-manual.md)：团队本地配置、Android 联调、owner-only 操作边界、日常排查。
- [backend/cloudbase-operations.md](backend/cloudbase-operations.md)：配置、运行、部署、测试命令和脚本行为。

## 前端与页面

- [frontend/overview.md](frontend/overview.md)：Flutter 目录结构、`AppScope`、Repository/Facade/Controller。
- [frontend/page-map.md](frontend/page-map.md)：页面口语、路由、主文件对照。
- [frontend/state-and-data-flow.md](frontend/state-and-data-flow.md)：页面监听关系、数据读写路径、排查顺序。
- [frontend/notification.md](frontend/notification.md)：统一通知通道、系统通知、通知中心。

## 设计与页面规范

- [design/design-system.md](design/design-system.md)：颜色、间距、圆角、字体、夜间情绪主题。
- [design/components.md](design/components.md)：共享组件清单和使用边界。
- [design/ui-alignment-checklist.md](design/ui-alignment-checklist.md)：UI 改动验收清单。
- [design/page-guides/home-pre-sleep.md](design/page-guides/home-pre-sleep.md)：睡前首页结构和交互。
- [design/page-guides/night-mood-welcome.md](design/page-guides/night-mood-welcome.md)：夜间情绪欢迎流程。
- [design/page-guides/dream-journal.md](design/page-guides/dream-journal.md)：梦记页结构、数据和助手 capture 关系。

## 模板

- [templates/issue_bug_template.md](templates/issue_bug_template.md)
- [templates/issue_feature_template.md](templates/issue_feature_template.md)

GitHub 上实际生效的 issue 表单位于 `.github/ISSUE_TEMPLATE/**`；这里保留 Markdown 版，主要用于飞书、会议纪要或不走 GitHub 表单的手工复制场景。

## 维护规则

- 后端接口变化：先改 `functions/src/http/app_api.ts`，再更新 [backend/api-reference.md](backend/api-reference.md)。
- 集合、字段、bootstrap payload、surface 变化：更新 [backend/data-model.md](backend/data-model.md)。
- CloudBase 本地配置、联调流程、owner-only 边界变化：更新 [backend/cloudbase-team-manual.md](backend/cloudbase-team-manual.md)。
- CloudBase 部署脚本、函数列表、运行命令变化：更新 [backend/cloudbase-operations.md](backend/cloudbase-operations.md)。
- 助手 provider、SSE event、turn lease、记忆写入变化：更新 [backend/assistant-runtime.md](backend/assistant-runtime.md)。
- Flutter 路由或页面文件变化：更新 [frontend/page-map.md](frontend/page-map.md)。
- `AppScope`、Repository、Facade、Controller 变化：更新 [frontend/overview.md](frontend/overview.md) 和 [frontend/state-and-data-flow.md](frontend/state-and-data-flow.md)。
- 共享组件或设计 token 变化：更新 [design/design-system.md](design/design-system.md) 或 [design/components.md](design/components.md)。
