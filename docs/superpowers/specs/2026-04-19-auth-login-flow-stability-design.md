# 登录页稳定性与重置密码分步流设计

**日期**: 2026-04-19

## 目标

只修复登录页两个前端问题：

1. 登录页在 CloudBase 鉴权状态变化时被整棵替换，导致输入内容丢失，表现为“失焦后像刷新一样清空”。
2. 找回密码在验证码验证成功后进入新页面时，页面仍然展示手机号、验证码和发送验证码区域，造成重复操作感。

## 约束

- 只改前端，不改后端接口与业务契约。
- 不修改版本号。
- 不顺手修别的问题。
- 不新增 Pencil 设计之外的全新 UI。
- 以最小必要改动为原则，优先复用现有内部页面切换与测试结构。

## 当前根因

### 1. 登录页“刷新清空”

`PhoneAuthPage` 的输入状态存放在页面 `State` 内部。一旦页面被卸载，所有 `TextEditingController` 内容都会丢失。

当前 `lib/app/app.dart` 中的 `_CloudBaseAuthGate` 在以下情况会直接返回 `_AuthLoadingPage`，从而替换掉整个路由子树：

- `!authRepository.hasCompletedInitialAuthBootstrap`
- `authRepository.isAuthenticating == true`

由于后台 bootstrap、恢复会话、宿舍定位同步等流程会再次触发 `ensureAuthenticated()`，登录页会在已显示后再次被换出，造成输入内容清空。

### 2. 重置密码页重复显示验证码区域

当前 `PhoneAuthPage` 已经把“验证验证码”和“设置新密码”混到了同一个内部页面。验证成功后只是追加了密码输入区，但手机号、验证码、发送验证码区域仍继续渲染，因此用户会在“新页面/下一步”里看到不必要的验证码操作区。

## 方案

### 1. 稳定 auth gate，不再卸载已显示的登录页

只在首次 CloudBase 鉴权 bootstrap 尚未完成时保留全屏 loading。首次 bootstrap 完成后，即使 `isAuthenticating` 再变化，也不再替换当前路由子树。

实现方式：

- 保留路由重定向逻辑不变。
- 收紧 `_CloudBaseAuthGate` 的显示条件：
  - 首次 bootstrap 未完成：显示 `_AuthLoadingPage`
  - 其余情况：始终返回 `child`

这样可以让 `/auth/phone` 在后台再次调用 `ensureAuthenticated()` 时继续保留在树中，避免输入状态丢失。

### 2. 恢复为“验证码页 -> 新密码页”的内部分步流

保留“验证码通过后进入下一页”的交互，不做同页合并。

实现方式：

- 恢复 `resetPassword` 内部视图。
- `forgotPassword` 视图只负责：
  - 手机号
  - 验证码
  - 发送验证码
  - 验证并继续
- `_verifyResetCode()` 成功后：
  - 调用现有验码接口获取 `PhoneVerificationProof`
  - 保存 proof
  - 切换到 `resetPassword` 视图
- `resetPassword` 视图只负责：
  - 新密码
  - 确认新密码
  - 确认重置密码
- 从 `resetPassword` 返回时：
  - 回到 `forgotPassword`
  - 清除本次 proof 和密码草稿，避免验证状态残留

## 测试策略

补充或调整 widget tests，覆盖以下行为：

1. CloudBase 环境下，登录页输入手机号后再次触发 `ensureAuthenticated()`，输入内容仍保留。
2. 验码成功后进入 `resetPassword` 视图时，不再显示手机号/验证码/发送验证码区域。
3. 从 `resetPassword` 视图按系统返回时，先回到验证码页，再返回登录页。

## 影响范围

- `lib/app/app.dart`
- `lib/features/auth/presentation/pages/phone_auth_page.dart`
- `test/widget_test.dart`

## 非目标

- 不改后端验证逻辑。
- 不改登录成功后的业务跳转。
- 不改注册流和短信登录流的业务语义。
