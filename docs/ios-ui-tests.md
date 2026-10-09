# iOS 原生界面回归

`RunnerUITests` 使用 XCTest 操作正常的 `lib/main.dart`，通过实际界面写入 SQLite，再终止并重启应用验证记录保留。没有替换数据库、绕过保存流程或给正式入口添加测试开关。

## 运行

需要 macOS、Xcode、Flutter，以及已安装的 iOS 模拟器运行时。先完成项目依赖安装，再运行：

```sh
flutter pub get --enforce-lockfile
bash tool/test_ios_ui.sh
```

默认使用 iOS 26.4 / iPhone 17 Pro。不同 SDK 安装可指定运行时和设备类型；Flutter 不在 PATH 时可指定其完整路径：

```sh
LALEMA_FLUTTER=/path/to/flutter/bin/flutter \
LALEMA_UI_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-26-4 \
LALEMA_UI_DEVICE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
bash tool/test_ios_ui.sh
```

脚本每次新建独立模拟器，不接受现有设备 UUID，也不会操作真机。结束时清理本次模拟器及临时构建目录，保留 `build/ui-test-results/run.*/` 中的构建日志、设备编号和 `.xcresult`。不要与其他 iOS 构建同时运行。

诊断时可设置 `LALEMA_KEEP_UI_SIMULATOR=1` 保留本次模拟器及构建目录；排查完毕应根据该次结果目录中的编号和路径清理。请通过脚本运行测试，不要直接对已有数据的安装运行 Runner-UI scheme。

## 覆盖与边界

- 全新安装没有记录；从底部入口选择 04 型，通过正常保存流程写入。
- 终止应用后重新启动，首页仍提供修改入口。
- 历史页包含且仅包含一条对应记录，避免只验证页面能够打开。
- 失败保存截图和可访问性树，成功保存历史页截图；均使用合成记录。

这是本地 iOS 模拟器回归，尚未加入远程 CI。它不代表文件保存/选取/恢复、通知权限/送达、身份验证、VoiceOver 或真机验收已通过；这些仍按发布验收清单单独验证。
