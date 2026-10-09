# iOS 原生界面回归

`RunnerUITests` 使用 XCTest 操作正常的 `lib/main.dart`，通过实际界面写入 SQLite，并使用真实系统文件面板验证备份恢复。没有替换数据库、绕过保存流程或给正式入口添加测试开关。

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
- 保存 JSON 到系统“我的 iPhone”，在应用中输入确认词清空本机记录，再从系统面板选择刚才的文件，预览并恢复。
- 取消文件选择后可重新打开；再次读取同一文件时，重复导入按钮禁用，原文件仍可读取。
- 恢复后及再次重启后都只有原来的一条记录，时间与形态标签一致。
- Flutter 滚动不受 XCTest 的原生空闲检测覆盖，点击滚动后的按钮前等待其位置稳定，避免滚动惯性导致漏点。
- 失败保存截图和可访问性树，成功保存历史页及重复导入预览截图；均使用合成记录。

这是本地 iOS 模拟器回归，尚未加入远程 CI。文件流程只覆盖系统本地提供者；它不代表 iCloud/第三方云盘、提供者离线、保存过程被中断、通知权限/送达、身份验证、VoiceOver 或真机验收已通过。Android 文件流程也仍需单独验证。
