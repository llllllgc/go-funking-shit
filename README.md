# 拉了么？Flutter 版

当前启用版本的 Flutter 复刻：一套 Dart 业务代码，同时保留 Android 与 iOS 平台工程。

## 已实现

- 今天：今日已记录次数、最近记录、修改、撤销与近 7 天像素风圆柱厕纸卷统计（有记录时展开，今天带绿芽）；次数仅统计已保存的记录
- 记录：七种形态按 01–07 显示，01 为光滑柔软、04 为颗粒偏硬；列表序号与内部形态编号分开，已有记录保持原图案和描述；日常记录点选即存，修改时可调整日期、时间和形态
- 操作反馈：记录成功短暂显示实际时间，并提供撤销；撤销或删除后提供 8 秒恢复入口，恢复保留原记录 ID、日期、时间和形态；开启无障碍导航时操作提示保留至手动关闭
- 历史：按日期倒序分组，可按显示的形态名称／序号搜索、按近 7／30 天或自选日期及形态筛选；保留“＋补记”、月历入口、修改和删除确认
- 月历：点击首页近七日的任一纸卷进入对应日期；按自然月查看，周一开始、六行日期，支持翻月和年月跳转
- 回到今天：月历右上角使用像素小日历＋“今”字，长按显示含义；今天与选中日期分别标识
- 补记：历史入口默认昨天，月历入口带入选中日期；支持中文日期/时间选择，禁止未来时间，失败保留输入
- 小纸条：本地离线知识库，按吃什么、形态、习惯、颜色和要留意筛选；首页根据最近形态给出一张纸条，展开后可查看依据与细节
- 所有记录按实际发生时间同步到首页、历史和月历；沿用已有 SQLite 字段，不迁移或清空旧记录
- 本地 SQLite 持久化；没有账户、网络、地图、AI 或旧 RPG 功能
- 本机记录读取失败时显示重试入口，读取成功前不会接受写入操作
- 复用原版 Zpix 字体、SVG 和批准透明 PNG
- Android/iOS 应用名称、图标和启动画面
- 320、375、414 与 768px 宽度布局测试

## 运行

```powershell
flutter pub get
flutter run
```

Windows 可以构建和运行 Android：

```powershell
flutter build apk --debug
```

## Android Studio 打包

用 Android Studio 打开项目根目录（含 `pubspec.yaml`），通过 **Build → Flutter → Build APK** 打包，或在项目终端运行：

```powershell
flutter build apk --release
```

正式 Release 必须先将 `android/key.properties.example` 复制为被 Git 忽略的 `android/key.properties`，填入本机密钥库的绝对路径、口令和别名；缺少配置时构建会明确失败，避免意外使用调试签名。安装包输出到 `build/app/outputs/flutter-apk/app-release.apk`。

如果出现 `The SDK is not specified for modules lalema, lalema_android`，在 **File → Project Structure** 中给项目选择本机已安装的 Android SDK，并让两个模块的 **Module SDK** 继承 **Project SDK**。当前本机项目配置关联 Android API 36；更换电脑时需重新选择已注册的 SDK。修改 IDE 配置文件后，关闭并重新打开项目使其生效。

iOS 代码位于 `ios/`，最终编译、签名和真机测试需要 macOS、Xcode 与 Apple 开发者配置：

```bash
flutter build ios
```

## 验证

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

GitHub Actions 还会检查锁文件依赖、Dart 格式、Flutter 分析与测试、Android Debug 和 iOS 模拟器构建，并验证无正式签名时 Android Release 被拒绝。

当前版本：`1.2.0+3`。交互草图位于 `tool/prototypes/`，用于设计留档，不会打包进 App。真实 Flutter 页面截图位于 `tool/captures/`，使用虚构演示记录。

## 开源许可

版权所有 © 2026 llllllgc 及贡献者。除下述单独授权的第三方内容外，本仓库的源码、文档和自有视觉素材采用 [GNU GPL v3.0 only](LICENSE) 许可。分发修改后的项目时，请遵守该许可证的条款。

`assets/fonts/zpix.ttf` 是 SolidZORO 的 Zpix 字体，不属于本项目的 GPL 授权范围；使用和再分发应遵守[字体作者的授权说明](https://github.com/SolidZORO/zpix-pixel-font/blob/main/README.md)。Flutter SDK 及第三方依赖遵循各自的许可证。
