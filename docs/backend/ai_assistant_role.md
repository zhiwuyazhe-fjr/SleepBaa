# AI 助手的作用

## 1. 它在项目里的定位

AI 助手不是一个独立的小聊天功能，而是整个应用里的“睡前总览与编排器”。

它的职责有两层：

- 对用户：用自然语言解释今晚状态、宿舍环境、最近睡眠和梦境趋势。
- 对系统：在合适的时候刷新首页建议、晨间反馈、画像报告和助手上下文。

所以它既要“能聊”，也要“能驱动页面更新”。

## 2. 它会读取哪些全局状态

每次编排时，后端都会把这些上下文拼起来：

- 用户资料 `users`
- 用户设置 `user_settings`
- 用户状态 `user_state`
- 宿舍信息 `dorms / dorm_members / dorm_events`
- 最近睡眠记录 `sleep_sessions`
- 最近梦境记录 `dream_entries`
- 当前线程消息 `assistant_messages`
- 助手画像 `assistant_profiles`
- 线程摘要和长期记忆

这意味着它的回复不应该一直重复一句模板，而应该随着上下文变化。

## 3. 它如何驱动前端

AI 助手成功运行后，不只是返回一句话，还会同步刷新相关 surface：

- `assistant_context`
- `home_pre_sleep`
- `morning_feedback`
- `profile_report`
- `sleep_mode`

常见情况：

- 用户在助手页提问后，会刷新 `assistant_context`，必要时顺带刷新 `home_pre_sleep`。
- 梦境新增后，会更新梦境分析，并驱动 `profile_report` 和 `assistant_context`。
- 睡眠会话完成并提交晨间反馈后，会更新画像总结、反馈闭环和报告卡片。

## 4. 真实模型与 fallback 的关系

当前默认主链路是：

- `AI_PROVIDER_MODE=cloudbase_ai`
- `AI_PROVIDER_BASE_URL=`
- `AI_PROVIDER_MODEL=hunyuan-2.0-instruct-20251111`

如果远端模型成功：

- `sourceMode=remoteSuccess`

如果远端失败，但 deterministic fallback 成功：

- `sourceMode=fallbackSuccess`

这样前端就能真实展示“联网成功”还是“回退回复”，不再把 fallback 伪装成远端成功。

补充约定：

- CloudBase 正式链路不再在 Flutter 端执行本地 stub fallback。
- 只有后端 deterministic fallback 才算 `fallbackSuccess`。
- 如果客户端没有拿到有效服务端结果，会显示 `sourceMode=error` 并提示重试。

## 5. 它不负责什么

AI 助手不负责：

- 直接决定 Flutter 页面布局
- 绕过后端直接把原始模型输出丢给前端
- 处理手机号登录注册本身
- 迁移旧匿名账号数据

它负责的是结构化分析与编排，不负责认证和视图层实现细节。


