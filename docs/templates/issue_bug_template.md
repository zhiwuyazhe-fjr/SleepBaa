# Bug Issue Template

用途：给不走 GitHub Issue Form 的场景使用，例如飞书、会议纪要、手工复制到聊天里。GitHub 仓库里真正生效的表单是 `.github/ISSUE_TEMPLATE/bug_report.yml`。

```markdown
### 问题描述
<问题是什么，影响了哪个用户流程>

### 复现步骤
1. <步骤 1>
2. <步骤 2>
3. <步骤 3>

### 期望行为
<正常情况下应该发生什么>

### 实际行为
<实际发生了什么>

### 严重程度
- [ ] 致命：崩溃、数据丢失、无法启动
- [ ] 严重：核心流程不可用
- [ ] 一般：部分功能受影响，有 workaround
- [ ] 轻微：UI、文案或轻微体验问题

### 相关模块
<home / sleep / dream / assistant / dorm / feedback / profile / notifications / auth / analysis / intervention / logs / night_mood / sleep_encyclopedia / core / functions / docs>

### 相关位置
- Route：
- File：
- API：

### 环境信息
- 设备：
- 系统版本：
- 后端模式：<in_memory / emulator / staging / production>
- App 版本或 commit：
- Flutter 版本：

### 日志或截图
```text
<粘贴关键日志；不要粘贴 access token、验证码、手机号等敏感信息>
```
```
