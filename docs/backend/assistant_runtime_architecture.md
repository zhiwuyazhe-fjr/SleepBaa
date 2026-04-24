# AI 助手运行架构

这份文档只讲现在真实在跑的架构，不讲历史方案。

当前目标有 3 个：

- 让用户尽快看到回复
- 让有价值的信息异步回流到首页和相关模块
- 让梦记、事记、线程摘要、长期记忆继续工作

## 1. 现在两档链路

### `reply_lite`

这是所有普通聊天的默认入口，包括轻互动。

现在都会进入正常聊天链路，只是只喂轻量上下文。

`reply_lite` 的目标是：

- 先尽快把回复流出来
- 不默认跑重分析
- 不阻塞用户看到正文

### `insight_full`

只有当这一轮对话真的包含高信息密度内容时才触发，比如：

- 睡不着
- 宿舍太吵
- 光线、手机、情绪压力
- 做梦、梦记
- 今晚计划、复盘

这一步才会做结构化提炼，并把结果回流到：

- `user_state`
- `card_snapshots`
- `assistant_thread_summaries`
- `assistant_memory_items`

## 2. 一条普通聊天消息会发生什么

用户发消息后：

1. 前端先本地插入用户气泡和 pending 助手气泡
2. 前端发起 `POST /api/assistant/reply/stream`
3. 后端先回 `ack`
4. orchestrator 构建 `reply_lite` 上下文
5. provider 调远端模型，流式产出 `message_delta`
6. 前端边收边改写助手气泡
7. 正文完成后，后端发 `message_completed`
8. 如果这轮内容值得深挖，再进入 `insight_full`
9. insight 完成后发 `surface_patch`、`memory_synced`、`done`

重点是：

- 用户先看到正文
- 卡片和记忆后补
- 不再等全量 `bootstrap` 才显示回答


## 4. 聊天失败时现在怎么处理

当前普通聊天的远端回复失败时：

- 不再自动回退到 deterministic 聊天文案
- SSE 直接发 `error`
- 前端把 pending 气泡改为 error
- 用户通过现有重试入口重发上一条消息

这解决的是之前那种怪体验：

- 正文看起来像正常回复
- 下面却挂着“回退回复 / The operation was aborted.”

现在的原则是：

- 远端成功，就给真实回复
- 远端失败，就明确失败
- 不再用备用聊天正文掩盖失败

注意：

- 结构化提炼
- 梦记/事记
- 晨间复盘

这些非首屏正文链路仍然可以保留 fallback，目的是保稳定性，不让整套结构化能力一起断。

## 5. 前端为什么还能继续更新首页卡片

因为消息流和数据回流已经拆开了。

### 消息流

只负责聊天体验：

- `ack`
- `message_delta`
- `message_completed`
- `error`

### 数据回流

只负责状态同步：

- `surface_patch`
- `capture_record`
- `memory_synced`
- `done`

前端收到 `surface_patch` 后会局部 merge 到 `CloudBaseSnapshotStore`。

这样做的结果是：

- 用户先看到回复
- 首页卡片稍后异步更新
- 不再每轮都被后台全量刷新拖住

## 6. 后台 reconcile 现在怎么做

系统仍然保留全量 `bootstrap` 校准，但它已经不是主链路了。

现在策略是：

- 优先使用 `surface_patch`
- 全量 refresh 作为后台 reconcile
- reconcile 做去抖和延后

所以体验上会变成：

- 聊天先快
- 卡片先 patch
- 全量数据晚一点自己对齐

## 7. 梦记和事记怎么走

梦记和事记继续走 `POST /api/assistant/capture/stream`。

流程是：

1. 先回 `ack`
2. 先给一小段确认文本
3. 结构化生成记录
4. 落库到 `sleep_capture_records`
5. 发 `message_completed`
6. 发 `surface_patch`
7. 发 `capture_record`
8. 发 `memory_synced`
9. 发 `done`

这部分没有取消 fallback，因为它们不是用户首屏的普通聊天正文。

## 8. 长期记忆写什么

长期记忆不是聊天备份，而是“值得跨轮记住的东西”。

典型会写入：

- 用户偏好
- 睡眠目标
- 宿舍上下文
- 稳定的睡眠模式
- 可复用的梦记/事记信息

轻互动本身不会因为取消 `fast_path` 就自动写进长期记忆。
是否写记忆，仍然由 `insight_full` 决定。

## 9. 当前关键接口

保留的接口：

- `POST /api/assistant/reply`
- `POST /api/assistant/reply/stream`
- `POST /api/assistant/capture`
- `POST /api/assistant/capture/stream`

其中：

- 普通聊天主体验依赖流式接口
- 非流式接口主要用于兼容和测试

## 10. 一句话总结

当前架构可以概括成一句话：

> 所有普通聊天先走轻量上下文回复，只有真正高价值的内容才进入深分析；聊天失败直接报错重试，不再用本地回退正文掩盖远端失败。
