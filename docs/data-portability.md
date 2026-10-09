# 备份、导出和恢复

入口：历史 → 备份、导出与恢复。

## 用户流程

- **完整备份**：保存全部记录为 JSON，包含备注和不适。系统文件选择器由用户选择保存位置；取消不改变日志，也不显示保存成功。备份未加密，选择云盘会交由相应服务保存。
- **CSV 导出**：选择近 7 天、近 30 天或全部，预览实际记录范围/数量。默认不包含细节，主动勾选才导出备注和不适。CSV 用于阅读，不能恢复。
- **恢复**：选择本应用 JSON 备份，先展示新增、重复和冲突数，再确认导入。同编号的重复内容跳过，冲突保留本机记录；用户应保留原备份以供核对。没有新增条目时不提供写入按钮。
- **清空**：必须输入“清空”后确认。仅删除本机日志和本次运行的恢复缓存，不删除导出的文件或设备系统备份。此操作没有短时撤销，应先保存备份。

## 文件协议

JSON 的 `formatVersion: 1` 独立于 App 版本和 SQLite schema 版本。字段为 `app: "lalema"`、`formatVersion`、`exportedAt`（Unix 毫秒）、`recordCount` 与 `records`。每条记录包括 `recordId`、`bristolType`、`recordedAt`、`updatedAt`、`note`、`discomforts`。

不适位值：腹痛 1、腹胀 2、急迫 4、费力 8，可相加。不记录为 0，不代表没有不适。备注最多 1000 个可见字符。

读取限制为 32 MB / 100000 条。校验版本、完整字段、数据类型、数量一致、时间范围、合法形态/不适和重复编号；文件内容被视为数据，不解释执行。未知字段或未来格式拒绝导入，避免旧版本静默丢失信息。备份时间超前时提示检查设备时间。

CSV 是带 BOM 的 UTF-8 文本，时间带本机对应日期的时区偏移。字段统一引用并转义引号、换行；公式前缀被当作文本处理。CSV 中的保护性文本处理不影响 JSON 的原始记录恢复。

## 数据完整性与验证

- 导入在 SQLite 单次事务内重算合并计划并批量插入；任何一条写入失败都会回滚。真实数据库触发器测试验证了中途失败的原子性。
- 成功导入/清空后更新控制器快照，不再依赖一次后续读取来报告成功。工作期间阻止重复操作。
- 文件选择/保存边界通过适配层测试验证。iOS 只清理本次操作在应用临时目录中的文件，不调用会清空整个临时目录的插件 API；原文件与其他临时文件保留。
- `test/record_archive_test.dart`：格式往返、损坏/不兼容文件、重复/冲突、CSV 与大小限制。
- `test/sqlite_repository_test.dart`：真实事务回滚、幂等导入、冲突保留、重开、清空。
- `test/data_controller_test.dart`：读取失败边界、写入失败重试、并发与旧恢复缓存。
- `test/data_flow_test.dart`：用户确认流程、默认隐私范围、取消/失败、双倍字号。
- `test/backup_files_test.dart`：原文件保留、单文件缓存清理、系统取消和保存结果。

## 原生文件选择器探针

`tool/file_dialog_probe.dart` 是独立 Debug 入口，仅用于隔离模拟器，不读取 App 数据库。它只提供空的合成备份；正式入口仍是 `lib/main.dart`。

```sh
flutter build ios --simulator --debug --no-pub -t tool/file_dialog_probe.dart --dart-define=FILE_DIALOG_PROBE=save
# 仅在独立测试模拟器安装/启动；检查系统保存面板。
flutter build ios --simulator --debug --no-pub -t tool/file_dialog_probe.dart --dart-define=FILE_DIALOG_PROBE=pick
# 检查 JSON 文件选择面板。
flutter build ios --simulator --debug --no-pub -t lib/main.dart
# 验证后恢复正常构建；探针产物不能当作应用交付。
```

原生面板呈现、文件适配层测试和真实数据库测试是不同层面的证据。仍需在真实 Android/iPhone 上验收完整的本地/云盘保存—选取—恢复流程、权限拒绝、提供者离线和应用中断。

文件选择 API 依据：[file_picker 官方文档](https://pub.dev/packages/file_picker)、[保存文件 API](https://pub.dev/documentation/file_picker/latest/file_picker/FilePicker/saveFile.html)。
