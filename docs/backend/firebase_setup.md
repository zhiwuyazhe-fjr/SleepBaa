# Firebase setup

## Projects

- `emulator`: local development only
- `staging`: shared team integration project
- `production`: demo or release project（可以先忽略）
<!-- emulator：你电脑本地跑的假 Firebase。数据只在你本机，不会上云，适合日常开发、改结构、测规则，出错也最安全。
staging：团队共享测试库。是真实云端 Firebase，但只放联调和测试数据，用来验证多人同步、真机上传、通知这些“本地模拟不够”的东西。
production：正式演示或发布库。只放最终数据，平时不要直接开发写它。 -->
## Local commands

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli #全局安装 FlutterFire CLI
# 然后将Flutterfire的路径加入环境变量
dart pub global run flutterfire_cli:flutterfire configure
#把当前 Flutter 项目连接到 Firebase,注意只勾选Android就行
firebase use --add 
#What alias do you want to use for this project? (e.g. staging) default

#本地开发
firebase emulators:start --project sleep-dorm-app
#然后新开一个终端，注意这两个终端必须同时开着
flutter run --dart-define=APP_BACKEND=emulator --dart-define=FIREBASE_PROJECT_ID=sleep-dorm-app
#意思一般是告诉你的 Flutter 代码：这次运行时，后端环境用 emulator，而不是 production/dev 线上环境。

#如果使用的安卓真机连接的安卓studio，需要在执行flutter run之前先进行端口映射
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9448 tcp:9448
adb reverse tcp:5001 tcp:5001
#如果你电脑里直接敲 adb 不能识别，就用完整路径（例如）：
& 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' reverse tcp:9099 tcp:9099
& 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' reverse tcp:8080 tcp:8080
& 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' reverse tcp:9448 tcp:9448
& 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' reverse tcp:5001 tcp:5001



#团队联调（此时不用端口映射）
flutter run --dart-define=APP_BACKEND=staging





```

## Required Flutter defines

- `APP_BACKEND=in_memory|emulator|staging|production`
- `APP_ID_PREFIX=com.dormsleep.app`
- `FIREBASE_PROJECT_ID=...`
- `FIREBASE_API_KEY=...`
- `FIREBASE_APP_ID=...`
- `FIREBASE_MESSAGING_SENDER_ID=...`
- `FIREBASE_STORAGE_BUCKET=...`

## Emulator ports

- Auth: `9099`
- Firestore: `8080`
- Storage: `9448`
- Emulator UI: `4000`

## Functions emulator

- The repo does not yet have a `functions/` project scaffold, so the default local workflow starts only `auth + firestore + storage`
- Add the Functions emulator back after you create a real `functions` source directory and callable implementation

## Notes

- Android package id is `com.dormsleep.app`
- iOS bundle id is `com.dormsleep.app`
- macOS bundle id is `com.dormsleep.app.macos`
- The app falls back to in-memory mode when Firebase runtime config is missing
- Assistant replies use a callable adapter named `assistantReply` and fall back to a local stub when the function is unavailable
