# 眠羊 SleepBaa 源码包说明

## 一、本文件夹作用

本文件夹用于提交参赛作品“眠羊 SleepBaa”的 Android 版本源码与相关素材。内容包含 Flutter 客户端业务源码、Android 平台工程、应用图片素材、CloudBase 云函数与后端接口源码、依赖锁定文件和构建/部署脚本，可用于审阅作品代码组成，并在具备相应环境时重新构建 Android 安装包。

本源码包不包含开发工具本体、第三方依赖源码、构建缓存、IDE 配置、iOS/Web/桌面端平台工程、团队云环境私密配置、账号密钥和正式签名证书。第三方依赖应根据 `pubspec.yaml`、`pubspec.lock`、`functions/package.json`、`functions/package-lock.json` 等配置文件重新安装。

## 二、文件与目录说明

1. `lib/`

   Flutter 应用主业务源码目录，包含页面、组件、路由、主题、状态管理、数据模型、Repository、Facade、Controller、通知、后端访问封装等核心代码。

2. `android/`

   Android 平台工程目录，包含 Gradle 构建配置、`AndroidManifest`、Kotlin 入口、应用图标、权限声明和启动资源等内容，用于构建 Android 安装包。源码包中已排除 `android/local.properties`、`.gradle`、`.kotlin` 等本机生成文件。

3. `assets/`

   应用内图片等资源素材目录，主要包括应用 Logo、梦境页面插图和睡眠百科模块图片素材。

4. `functions/`

   CloudBase 后端与云函数源码目录，包含 `app-api` HTTP Function、睡眠记录和梦境记录事件函数、TypeScript 源码、部署包入口、后端依赖配置和测试源码。源码包中未包含 `node_modules` 和编译生成的 `lib` 目录。

5. `scripts/`

   本项目 Android 联调和 CloudBase 函数部署脚本目录。当前包含 `run_android_cloudbase.ps1` 和 `deploy_cloudbase_functions.ps1`。

6. `pubspec.yaml`

   Flutter 项目配置文件，声明项目依赖、Dart SDK 约束、Flutter 资源目录和应用基础信息。

7. `pubspec.lock`

   Flutter/Dart 依赖版本锁定文件，用于提高重新安装依赖和复现构建结果的稳定性。

8. `analysis_options.yaml`

   Dart/Flutter 静态分析规则配置文件。

9. `.cloudbase.local.example.json`

   CloudBase 本地配置示例文件，用于说明 CloudBase 联调时需要准备的字段。真实 PublishableKey、团队云账号凭据和本地私密配置未随源码提交。

10. `run_android_cloudbase.cmd`

    Windows 下启动 Android CloudBase 联调的入口脚本，会调用 `scripts/run_android_cloudbase.ps1`。

11. `deploy_cloudbase_functions.cmd`

    Windows 下部署 CloudBase 函数的入口脚本，会调用 `scripts/deploy_cloudbase_functions.ps1`。

12. `README.md`

    本说明文件，用于说明提交包用途、文件内容、排除项、Android 安装包复现方式，以及 API 调用大模型的关键代码位置。

## 四、未包含内容说明

1. CloudBase 私密配置

   团队正式 CloudBase 环境的 PublishableKey、云账号凭据、权限配置、线上数据和本地 `.cloudbase.local.json` 属于访问控制和安全敏感内容，不能随公开源码包提交。源码包只提供配置模板和后端源码。

2. Android 正式签名信息

   正式签名证书、签名密码、`key.properties`、`jks/keystore` 文件未包含在源码包中。评审环境自行构建出的 APK 可能使用默认调试签名或本地签名，不等同于团队正式发布包签名。

3. 构建缓存和依赖目录

   `build`、`.dart_tool`、`functions/node_modules`、`functions/lib` 等目录未包含。评审或开发者应通过 Flutter、npm 和 Gradle 的依赖配置重新生成。

4. 非 Android 平台工程和开发文档

   本次只提交 Android 源码包，因此未包含 `ios`、`web`、`windows`、`macos`、`linux`、`docs` 等目录。

5. 云端音频素材

   作品中使用的助眠音频文件已上传至团队 CloudBase 云存储，由后端接口在运行时生成可播放地址并返回给客户端。由于音频文件依赖 CloudBase 存储权限、临时访问链接和团队云环境配置，未作为本地文件放入源码包。未配置 CloudBase 时，源码仍可构建并查看音频入口界面，但无法播放团队云端音频资源。

## 五、Android 安装与复现说明

### 1. 普通用户安装方式

普通用户可使用参赛团队提供的 Android APK 安装包，在 Android 真机或 Android 模拟器中直接安装体验。设备需为 Android 6.0 及以上系统，对应本项目 Android `minSdk 23`。首次打开应用后，根据页面流程完成注册登录和必要授权；通知、麦克风、相机或本地存储等权限会影响提醒、噪声监测、灯光检测和相关辅助功能。

普通用户安装的团队 APK 已按团队环境完成后端配置，可用于体验完整功能。源码包本身不直接包含团队正式云环境密钥。

### 2. 开发环境要求

注意：Windows 环境下，Flutter/Android 构建工具对包含中文字符的项目路径兼容性较差。若源码包位于含中文的目录中，建议先复制到纯英文路径并将 `素材源码` 重命名为英文名，例如 `C:\SleepBaaSource`，再执行构建命令。

重新构建 Android 安装包前，建议准备以下环境：

- Flutter SDK 和 Android 开发环境
- Android Studio、Android SDK、Android 真机或模拟器
- Dart SDK 约束参考 `pubspec.yaml`，当前项目约束为 `^3.11.4`
- JDK 17 或兼容 Android Gradle 构建要求的 JDK
- Node.js，后端 `functions/package.json` 中声明运行环境为 Node 20
- 可访问 Flutter、Gradle、npm 依赖源的网络环境

### 3. 不加 CloudBase 的本地内存模式

该方式不注入 CloudBase 配置，客户端会使用 in-memory 本地后端，适合检查界面、路由、页面交互和本地基础流程。因为没有连接团队云环境，登录、远端数据同步、云函数、触发器和 AI 后端能力不会完整生效。

操作步骤：

```powershell
flutter pub get
flutter build apk --no-tree-shake-icons
```

构建完成后，APK 通常生成于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

### 4. 加 CloudBase 的完整联调模式

该方式用于复现客户端与 CloudBase 后端的完整联调效果。需要先准备有效的 CloudBase 环境、PublishableKey 等云函数部署权限。

操作步骤：

```powershell
# 1. 将 .cloudbase.local.example.json 复制为 .cloudbase.local.json
# 2. 按模板补充有效 CloudBase 配置
flutter pub get
flutter build apk --dart-define-from-file=.cloudbase.local.json --no-tree-shake-icons
```

设备联调可执行：

```powershell
.\run_android_cloudbase.cmd
```

APK 输出位置通常为：

```text
build/app/outputs/flutter-apk/app-release.apk
```

### 5. CloudBase 后端说明

`functions/` 目录中保留了作品使用的 CloudBase 后端源码，包括 `app-api` HTTP Function、睡眠记录事件函数和梦境记录事件函数。后端用于提供认证相关访问、远端数据读写、云函数触发器、AI Provider 和云端音频目录等能力。

但是 CloudBase 完整联调依赖真实 PublishableKey、团队云环境访问权限、云账号认证和线上数据库权限。这些内容具备访问控制属性，公开提交会造成账号、数据或服务被未授权调用的风险，因此不能放入源码包。

因此，评审环境仍可按“不加 CloudBase 的本地内存模式”构建出可运行 APK，用于查看 Android 客户端界面和本地交互；但无法完整复现登录、远端数据、云函数触发器、AI 后端回复等依赖团队云环境的能力。

完整运行效果以团队提交的 APK、演示视频和答辩材料为准。

## 六、API 调用大模型重点说明

本作品的大模型调用集中在 CloudBase 后端函数中，客户端不直接保存或调用大模型 API Key。Flutter 客户端只通过 CloudBase HTTP API 与后端通信，由后端根据环境变量选择具体 AI Provider、模型和调用方式。

### 1. 客户端到后端的调用入口

- `lib/core/backend/cloudbase_app_api_client.dart`：封装 CloudBase App API 请求和 SSE 流式响应。
- `lib/core/backend/assistant_reply_gateway.dart`：助手能力网关，调用以下后端接口：
  - `/api/assistant/reply/stream`：睡前助手对话流式回复。
  - `/api/assistant/capture/stream`：睡前“梦记/事记”流式收纳与 AI 整理。

### 2. 云函数 HTTP API 入口

- `functions/src/http/app_api.ts`：CloudBase `app-api` HTTP Function 的 Express 入口，会在相关路由中调用 `createAIProviderFromEnv()` 创建大模型 Provider。
- 重点路由包括：
  - `/api/assistant/reply` 与 `/api/assistant/reply/stream`
  - `/api/assistant/capture` 与 `/api/assistant/capture/stream`
  - `/api/cards/refresh`
  - 睡眠记录、梦境记录、夜间心情等会触发计划刷新、梦境分析或画像更新的接口

### 3. 云函数事件触发入口

- `functions/on-sleep-session-write/index.js`：睡眠记录写入后触发，调用后端编排逻辑更新用户状态、晨间反馈和卡片快照。
- `functions/on-dream-entry-write/index.js`：梦境记录写入后触发，调用 AI Provider 生成梦境摘要、主要情绪和建议关注点。

### 4. 大模型 Provider 工厂与可配置模型

- `functions/src/providers/provider_factory.ts`：大模型 Provider 工厂与远程调用实现。
- `functions/src/providers/ai_provider.ts`：本地规则兜底 Provider 和统一接口定义。
- 关键环境变量：
  - `AI_PROVIDER_MODE`：选择 Provider，支持 `cloudbase_ai`、`xai_responses`、`deterministic`。
  - `AI_PROVIDER_MODEL`：主模型名称。
  - `AI_PROVIDER_MODEL_REPLY`：助手普通对话回复模型覆盖项。
  - `AI_PROVIDER_MODEL_STRUCTURED`：结构化 JSON 任务模型覆盖项。
  - `AI_PROVIDER_API_KEY`、`AI_PROVIDER_BASE_URL`、`AI_PROVIDER_GROUP`：远程 API 或 CloudBase OpenAI-compatible 网关配置。
  - `AI_PROVIDER_TIMEOUT_MS`、`AI_PROVIDER_TIMEOUT_MS_REPLY`、`AI_PROVIDER_TIMEOUT_MS_STRUCTURED`：超时控制。

### 5. 大模型参与的业务能力

后端统一通过 `AIProvider` 接口承载大模型能力，主要包括：

- `streamReplyText`：生成睡前助手对话回复，支持流式输出。
- `extractTurnInsights`：从对话中提取宿舍噪声、灯光、手机使用、情绪压力等干扰线索，并沉淀长期记忆候选。
- `generateConversationTitle`：自动生成对话标题。
- `generateTonightPlan`：生成今晚睡眠建议计划和推荐动作。
- `summarizeDream`：分析梦境文本，生成摘要、主要情绪和建议关注点。
- `generateSleepCapture`：将睡前梦记/事记整理为标题、提纲、正文和助手回应。
- `analyzeFeedback`：根据晨间反馈更新睡眠画像和后续建议。

源码包不包含真实 API Key、`.cloudbase.local.json`、云账号凭据和线上数据库权限；这些信息只在团队部署环境或构建 APK 时通过安全配置注入。

## 七、代表性素材说明

1. `assets/images/logo.png`

   应用 Logo 图片素材。

2. `assets/images/dream_top.png`

   梦境相关页面顶部插图素材。

3. `assets/images/sleep_encyclopedia/`

   睡眠百科模块使用的场景图片素材。

4. `android/app/src/main/res/`

   Android 平台启动图标、启动背景和其他平台资源。

5. CloudBase 云存储中的助眠音频

   本作品助眠音频素材托管在团队 CloudBase 云存储中，用于应用内助眠音频播放。该类素材不随源码包直接提交，完整播放效果以配置 CloudBase 后的运行结果或团队提交的 APK 为准。

本作品界面主要由 Flutter 组件、主题样式、Material 图标和上述图片素材共同构成，因此未额外拆分独立素材包。
