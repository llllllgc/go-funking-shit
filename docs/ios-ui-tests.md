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

默认依次运行三个场景，每个场景都新建独立模拟器，不接受现有设备 UUID，也不会操作真机。通知权限由系统保存，因此权限场景不能复用同一个设备来冒充首次启动。每项结束时清理该模拟器及临时构建目录，保留 `build/ui-test-results/run.*/` 中的构建日志、设备编号和 `.xcresult`。不要与其他 iOS 构建同时运行。

只排查一个场景时，可以设置 `LALEMA_UI_TEST`，例如：

```sh
LALEMA_UI_TEST=testReminderPermissionRecoveryAndDelivery bash tool/test_ios_ui.sh
```

另外两个场景名为 `testRecordPersistsAndBackupRestoresThroughSystemFiles` 和 `testFirstNotificationApprovalPersists`。当前验收环境为系统英文、应用中文；原生系统控件按这一环境定位。

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
- 首次主动开启时，在真实授权弹窗选择允许；核对每日提醒安排状态、重启保留，以及关闭。
- 另一台全新模拟器先拒绝授权，确认提醒保持关闭；通过系统界面重新允许，返回后识别新权限，仍需用户主动开启每日提醒。
- 系统直达链接若仅打开设置首页，测试沿可见的 Apps → 拉了么？ → Notifications 路径操作，日志明确区分直接进入与手动路径；不会改写系统权限数据库。
- 发送测试提醒、返回桌面、观察系统通知正文并点击返回应用；随后关闭提醒并重启核对关闭状态。

这是本地 iOS 模拟器回归，尚未加入远程 CI，具体通过结果见发布验收记录。文件流程只覆盖系统本地提供者；通知送达用的是用户触发的测试提醒，不代替每日指定时间到达、时区变化、专注模式、锁屏或开启应用锁后的通知点击验证。iCloud/第三方云盘、提供者离线、保存过程被中断、身份验证、VoiceOver、Android 和真机仍需单独验收。
