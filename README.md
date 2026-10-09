# 拉了么？Flutter 版

本地离线的排便记录应用，使用 Flutter / SQLite，同时支持 Android 与 iOS。

## 已实现

- 今天：今日次数、最近记录、修改、撤销与近 7 天像素风圆柱厕纸卷统计（有记录时展开，今天带绿芽）
- 首页最近记录提供“按上次形态记录”快捷入口，复用上次 Bristol 形态并保留完整记录入口
- 观察卡支持 7 天 / 30 天切换：显示有记录的天数、记录总数、日均记录数和 Bristol 分布；样本较少时不作健康判断
- 记录：Bristol 01–07 形态选择，日常记录点选即存；修改记录时可调整日期、时间和形态，确认后保存；记录页提供按需打开的形态说明
- 可选细节：腹痛、腹胀、急迫、费力及最多 1000 字备注；填写细节后确认保存，返回时保护未保存的备注；快捷记录不会复制上一次的不适
- 历史：按日期倒序分组、右上角“＋补记”、月历入口、修改和带记录详情的删除确认
- 月历：点击首页近七日的任一纸卷进入对应日期；按自然月查看，周一开始、六行日期，支持翻月和年月跳转
- 回到今天：月历右上角使用像素小日历＋“今”字，长按显示含义；今天与选中日期分别标识
- 补记：历史入口默认昨天，月历入口带入选中日期；支持中文日期/时间选择，禁止未来时间，失败保留输入
- 小纸条：本地离线知识库，按吃什么、形态、习惯、颜色和要留意筛选；首页根据最近形态给出一张纸条，展开后可查看依据与细节
- 所有记录按实际发生时间同步到首页、历史和月历；SQLite v1 自动升级至 v2，保留旧记录 ID、发生时间与更新时间，新增细节字段默认为空
- 本地 SQLite 持久化；没有账户、网络、地图、AI 或旧 RPG 功能
- 删除后提供短时撤销恢复；切换到今天或选择时间时会即时限制未来时刻
- 首页和知识库按全量记录中的最近一笔推荐纸条；历史页系统返回回到首页，平板内容列保持可读宽度
- 复用原版 Zpix 字体、SVG 和批准透明 PNG
- Android/iOS 应用名称、图标和启动画面
- 启动读取失败显示可重试页面；重试不清空数据库
- 320、375、414 与 768px 布局测试，新增 320px 双倍字号与横屏细节记录测试

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

安装包输出到 `build/app/outputs/flutter-apk/app-release.apk`。当前 Release 使用测试签名。

如果出现 `The SDK is not specified for modules lalema, lalema_android`，在 **File → Project Structure** 中给项目选择本机已安装的 Android SDK，并让两个模块的 **Module SDK** 继承 **Project SDK**。当前本机项目配置关联 Android API 36；更换电脑时需重新选择已注册的 SDK。修改 IDE 配置文件后，关闭并重新打开项目使其生效。

iOS 代码位于 `ios/`，最终编译、签名和真机测试需要 macOS、Xcode 与 Apple 开发者配置：

```bash
flutter build ios
```

## 验证

```powershell
dart analyze --format machine .
flutter test
flutter build apk --debug
```

固定验证环境：Flutter `3.44.9` / Dart `3.12.2`。CI 执行格式检查、静态分析、单元/界面/真实 SQLite 测试，以及 Android Debug / iOS 模拟器构建。SQLite 测试使用独立临时数据库，不读写用户记录。

2026-10-09 已在 macOS 上实际运行分析与回归，并完成 iOS 模拟器构建/启动。详见 [发布准备与验收](docs/release-readiness.md)，包含尚未完成的发布条件。iOS 最低部署版本为 15.0（当前 Xcode 27 构建要求）。

删除应用可能一并删除本地记录；系统设备备份是否包含应用数据取决于平台与设备设置。应用内导出/恢复尚在开发计划中，不能将当前版本称为完整发布版本。

当前开发版本：`1.5.0+6`。交互草图位于 `tool/prototypes/`，用于设计留档，不会打包进 App。真实 Flutter 页面截图位于 `tool/captures/`，使用虚构演示记录。
