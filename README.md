# Sleep Dorm App

Sleep Dorm App 是一个面向宿舍睡眠场景的 Flutter 应用。当前项目采用 Flutter 客户端加 CloudBase HTTP Function/事件函数的结构；客户端通过 Repository、Facade、Controller 访问 in-memory 或 CloudBase 实现。

## 快速入口

- 文档总入口：[docs/README.md](docs/README.md)
- Flutter 入口：[lib/main.dart](lib/main.dart)
- 应用装配：[lib/core/app_scope.dart](lib/core/app_scope.dart)
- 路由表：[lib/app/routes.dart](lib/app/routes.dart)
- CloudBase HTTP API：[functions/src/http/app_api.ts](functions/src/http/app_api.ts)

## 本地运行

默认不传 `--dart-define` 时使用 in-memory 后端，适合快速 UI 与交互调试。

```powershell
flutter pub get
flutter run
```

CloudBase Android 联调使用本地配置文件：

```powershell
.\run_android_cloudbase.cmd
```

需要先按 `.cloudbase.local.example.json` 准备 `.cloudbase.local.json`。

## 后端函数

CloudBase 函数源码在 `functions/src`，部署包入口包括：

- `functions/app-api`
- `functions/on-sleep-session-write`
- `functions/on-dream-entry-write`

常用命令：

```powershell
npm --prefix functions test
.\deploy_cloudbase_functions.cmd
```

更多说明见 [docs/backend/cloudbase-operations.md](docs/backend/cloudbase-operations.md)。
