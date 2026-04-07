# 梦境模块接口

## 前端入口

- `DreamFacade.saveDraft(...)`
- `DreamFacade.entries`
- `DreamFacade.latestEntry`

## Flutter 调用链

- facade -> `DreamRepository`
- repository -> `POST /api/dream/save`

## CloudBase 路由

### `POST /api/dream/save`

请求：

```json
{
  "entry": {
    "id": "dream-123",
    "title": "考试教室",
    "body": "我一直找不到教室门，心里越来越急。",
    "tags": ["考试"],
    "emotionLabel": "不安",
    "sessionId": "session-123"
  }
}
```

返回：

```json
{
  "entryId": "dream-123",
  "analysis": {
    "summary": "这条梦境更像是在投射紧张和迟到压力。",
    "dominantEmotion": "不安",
    "suggestedFocus": "routine",
    "sourceRefs": ["dream_entries.body"]
  },
  "updatedSurfaces": ["profile_report", "assistant_context"]
}
```

## 涉及集合

- `dream_entries`
- `user_state`
- `card_snapshots`

## 触发器

- `on-dream-entry-write`

## 是否依赖真实 AI

- 否，fallback 可以先生成结构化梦境摘要
- 是，后续可在 `cloudbase_ai` / `external_http` 模式下增强质量
