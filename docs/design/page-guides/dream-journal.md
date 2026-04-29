# Dream Journal Page Guide

最后核验日期：2026-04-29。代码入口：`lib/features/dream/presentation/pages/dream_journal_page.dart`。

## 路由

| Route | Page |
| --- | --- |
| `/dream/journal` | `DreamJournalPage`。 |
| `/dream/detail` | `DreamDetailPage`。 |

## 页面结构

`DreamJournalPage` 使用 `DefaultTabController` 和 `TabBarView`，当前三个 tab：

| Tab | Widget | 说明 |
| --- | --- | --- |
| 梦境列表 | `_DreamListTab` | 合并助手 capture 的 dream 记录和静态 `DreamContent.entries`。 |
| 梦境映射 | `_DreamMappingTab` | 根据最近 dream capture 记录生成 pattern 和 insight。 |
| 新建梦记 | `_DreamCreateTab` | 输入标题/内容并保存为 `SleepCaptureType.dream`。 |

## 状态源

- 助手 capture 记录来自 `sleepCaptureRepository.recordsByType(SleepCaptureType.dream)`。
- 静态展示内容来自 `lib/features/dream/presentation/dream_content.dart`。
- 保存新梦记时写入 `SleepCaptureRepository`，CloudBase 模式对应 `/api/sleep-capture/save`。

## 视觉资源

梦境映射 tab 使用：

- `assets/images/dream_top.png`

改资源时要同步 `pubspec.yaml` asset 声明，并在页面上检查加载失败状态。

## 分析逻辑

`_buildDreamAnalysis(records)` 当前行为：

- 没有 capture 记录时使用 `DreamContent.highlight`、`patterns`、`insights`。
- 有记录时取最近 12 条 dream capture。
- 基于记录内容推导 pattern label。
- 最新记录决定 highlight 和若干 insight 文案。

这部分是前端展示分析，不等同于后端 `dream_entries` 的 AI 分析。

## UI 约束

- Tab 页滚动底部保留约 120 留白。
- 列表卡片使用 `AppRadius.cardLarge` 和 `AppColors.cardShadow`。
- 梦境映射中的统计块要能处理 0 条、1 条和多条 capture。
- 新建梦记页提交后应避免重复保存，并给出可见反馈。

## 与助手 capture 的关系

助手页面进入睡前 capture 模式时：

```text
/assistant?flow=sleep_capture&mode=dream&sessionId=...
```

capture 成功后，后端返回 `capture_record`，Flutter 写入 `SleepCaptureRepository`，梦记页再读取该 repository。不要让梦记页直接解析助手消息文本。

## 改动检查

- 改 tab 数量：检查 `DefaultTabController.length`、`TabBar.tabs`、`TabBarView.children` 是否一致。
- 改 dream 数据结构：同步 `SleepCaptureRecord`、serializer 和后端 capture record。
- 改保存入口：同步 `/api/sleep-capture/save` 和助手 capture 流。
