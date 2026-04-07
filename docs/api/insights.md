# 洞察与报告接口

## 前端入口

- `InsightsFacade.refresh()`
- `InsightsFacade.interferenceInsights`
- `InsightsFacade.currentReport`

## Flutter 调用链

- facade -> `InsightsRepository`
- repository -> `POST /api/cards/refresh`
- repository -> `CloudBaseSnapshotStore.refresh()`

## CloudBase 路由

### `POST /api/cards/refresh`

请求：

```json
{
  "surfaces": ["home_pre_sleep", "profile_report"]
}
```

返回：

```json
{
  "version": "v-1712400000000",
  "updatedSurfaces": ["home_pre_sleep", "profile_report"]
}
```

## 主要数据来源

- `card_snapshots/home_pre_sleep`
- `card_snapshots/profile_report`
- `user_state.tonightPlan`

## repository 策略

- 优先读 `card_snapshots`
- 无快照时 fallback 到本地推导逻辑

## 与 AI 的关系

- 洞察页本身不直接调 AI
- AI 先写 `card_snapshots`
- 洞察页只消费结构化结果
