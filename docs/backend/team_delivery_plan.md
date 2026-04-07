# 团队交付计划

## 1. 当前冻结的共享契约

本轮所有队员都按以下契约继续开发，不要反向改基础架构：

- 客户端统一走 CloudBase Auth HTTP + `app-api`
- 不直连业务库
- AI 主链路固定为：
  - `prepareTonightPlan`
  - `assistantReply`
  - `onSleepSessionWrite`
  - `onDreamEntryWrite`
- 宿舍主链路固定为：
  - `POST /api/dorm/create`
  - `POST /api/dorm/invite/create`
  - `POST /api/dorm/invite/accept`
- 手机号绑定固定走：
  - 发送验证码
  - 校验验证码
  - `POST /api/auth/link-phone`

## 2. 我已经先完成的部分

- CloudBase 数据层接线
- `app-api` 主链路
- 睡眠 / 梦境 / 晨间反馈闭环
- 宿舍创建与邀请 MVP
- 手机号绑定 MVP
- 设置页去 Firebase 残影
- 宿舍邀请页首轮流
- 中文总手册和核心 API 文档

## 3. 队员 A：睡眠闭环增强

先做：

- 补 `sleep_sessions` 相关单测
- 补晨间反馈分析规则
- 补 `feedbackLoop` 趋势统计

后做：

- 连续多夜趋势分析
- 推荐动作有效性排行

依赖：

- 依赖当前 `user_state`、`feedbackLoop`、`profile_report` 契约

交付物：

- 睡眠闭环单测
- 趋势统计规则
- 晨间反馈增强文档

## 4. 队员 B：宿舍协作增强

先做：

- `dorm_invites`、`dorm_members` 权限补测
- 宿舍事件文案与通知收口
- 邀请码失效 / 过期处理

后做：

- 宿舍卡片聚合增强
- 邀请消息去客户端化

依赖：

- 依赖当前 `POST /api/dorm/create`
- 依赖当前 `POST /api/dorm/invite/create`
- 依赖当前 `POST /api/dorm/invite/accept`

交付物：

- 宿舍邀请链路补测
- 邀请码状态处理
- 宿舍通知增强

## 5. 队员 C：AI 增强

先做：

- 在 `AIProvider` 接口下增强意图分类
- 增强梦境情绪标签提取
- 增强晨间反馈摘要质量

后做：

- 接真实 CloudBase AI 或外部 HTTP AI
- 画像摘要增强
- 更细的情绪趋势分析

依赖：

- 依赖当前 `functions/src/providers/provider_factory.ts`
- 依赖当前 deterministic fallback 契约

交付物：

- provider 层增强实现
- AI 回归测试
- Prompt / 结构化结果规范文档

## 6. 联调顺序

推荐按这个顺序联调：

1. `.\deploy_cloudbase_functions.cmd`
2. `.\run_android_cloudbase.cmd`
3. 验证匿名登录
4. 验证今晚建议
5. 验证睡眠模式
6. 验证梦境记录
7. 验证晨间反馈
8. 验证宿舍创建 / 加入 / 邀请
9. 验证手机号绑定
10. 验证 assistant 对话

## 7. 不允许碰的内容

- `docs/backend/firebase_setup.md`
- 未授权页面的 `presentation` 布局
- 已冻结的 BFF 路由名
- 已冻结的集合名和主键规则

## 8. 当前剩余风险

- 数据库触发器仍需要控制台手动配置
- 真实 AI provider 接入后还要再做一轮结构化校验
- 宿舍邀请码的长期治理策略还没做完
- 手机号绑定目前只绑定资料，不做账号合并
