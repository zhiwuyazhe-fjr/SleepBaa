# 团队分工计划0409-0412

## 1. 一些说明


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
- 中文总手册和核心 API 文档

## 3. 杨：AI增强 

目前AI仅仅是能回答，但是和前端的联动相关链路仍然不行
1、AI回答速度太慢，我现在是模仿Openclaw做了部分持久化记忆，但是带来了上下文冗余的问题
导致回答太慢，可以结合你的知识重塑这方面逻辑。（模型我接入的是qwen-3.5 plus）

目前项目里“模仿 OpenClaw 的 MD 文档”分两类：
第一类是仓库里的设计文档，它们是本地代码仓里的说明文档，不是用户运行时记忆：
- [assistant_memory_architecture.md]
- [assistant_context_engine.md]
- [assistant_memory_operations.md]
第二类是运行时真正对应 OpenClaw “memory” 思路的数据，它们不是本地 Markdown 文件，而是云端 CloudBase 集合。文档里也明确写了：OpenClaw 用 Markdown 做 source of truth，而这个项目把它改成了 CloudBase 持久化。
现在真正存用户记忆的是云端这些集合：
- `assistant_thread_summaries`
- `assistant_memory_items`
- `assistant_threads`
- `assistant_messages`
- `user_state`

而且 assistant 每次回复成功后，会把 thread summary 和 long-term memory 写回云端，不存在用户本地 Markdown 里。相关文档：[assistant_orchestrator.ts][firestore_repositories.ts]

2、完善根据梦记/事记模块，用户给了信息，AI输出的提示词预置以及结构化整合后在梦境记录和事记仓库中呈现的逻辑。

3、晨间反馈页面空白，是不是没有集成main的逻辑？还是说没有模拟数据？

4、睡眠模式下的“灵感记事”，梦记和事记都无法正常工作。显示“暂时没有收到整理结果...."接入后端之后，这个地方我后端还没打通。。。

5、睡眠模式下，需要点击两次“结束睡眠模式”才能退出的bug。我建议结束睡眠模式保留继续弹层，但弹层按钮改成 返回 / 退出 / 进入晨间反馈



## 4. 陈：宿舍协作增强

1、宿舍规则制定的落地
2、安静挑战功能的完善或者替换
3、室友状态和安静等级在该页面的同步
4、宿舍噪音检测功能的实现和前端展示
5、勋章功能完善和优化

## 5. 魏：前端统一UI
1、按照你昨天晚上说的统一UI
- 着重解决一下AI助手的界面（输入框，整体风格和心情的适配，消息框等等）
- 睡眠模式下，四个按键的像素显示有问题
- 委婉提醒按钮太靠下，被底部tab遮挡（如图）
- 设置界面里面“账号与安全”模块下面的“手机号登录与验证”按钮去掉，只保留退出登录
- 头像在首次设置成功之后，再次修改会出现无法更新头像，显示如图所示的bug，显示CloudBaseAppApiException [500]{FUNCTION_EXECUTE_FAIL}:
Function invoke failed. For more
information, please refer to https://docs.cloudbase.net/error-code/
service/FUNCTION_EXECUTE_FAIL
- 修改宿舍名称后出现bug，显示红色报警页面 “TextEditingController was used after being disposed”

2、把issue清空！！！！！


## 6. 范：继续完善睡眠闭环的逻辑实现
1、今晚行动建议和今晚影响因素的逻辑实现
2、连续多夜趋势分析，睡眠打卡日历的逻辑实现
3、音频播放模块
