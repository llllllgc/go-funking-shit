# iPhone 截图草案与复现

截图用原生 iOS 模拟器渲染生产页面，数据来自内存中的固定合成记录，不读取正式 SQLite 日志。日期和状态栏按示例固定；展示夹具的部分导航回调停用，因此截图不是完整交互或真机测试证据。

画面由系统直接输出为 JPEG，没有后期修改界面。两组目标为 iPhone 17 Pro（1206×2622）和 iPhone 17 Pro Max（1320×2868）；这些尺寸列在 [Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) 中。最终提交仍需核对平台当时的要求、对应设备和最终发布版本。

## 画面与建议说明

| 文件 | 建议说明 | 用途 |
| --- | --- | --- |
| today.jpg | 今天的记录，随时回顾 | 商店截图草案 |
| record.jpg | 选择形态，按需补充细节 | 商店截图草案 |
| history.jpg | 按关键词和日期查找 | 商店截图草案 |
| data.jpg | 备份与导出，由自己掌握 | 商店截图草案 |
| settings.jpg | 按自己的节奏设置提醒与隐私 | 商店截图草案 |
| knowledge.jpg | 阅读有出处的小纸条 | 商店截图草案 |
| about.jpg | 帮助、隐私说明和实际安装版本 | 开发验收，发布者信息确认后再选用 |

## 复现

先准备专用、名称以 `Lalema ` 开头的隔离模拟器。不要选择存放真实个人记录的设备。使用本机 Flutter 可执行文件路径和模拟器 UUID：

```sh
LALEMA_FLUTTER=/path/to/flutter \
LALEMA_CAPTURE_SIMULATORS=isolated-uuid-1,isolated-uuid-2 \
bash tool/capture_store_screenshots.sh
```

需要排查单页时，可设 `LALEMA_CAPTURE_SCREENS=record`。采集器会先等待应用写出当前画面的元数据，核对合成数据标记、页面名称、渲染错误及状态栏安全区，再采集图片。仍须人工查看图片，不能仅凭元数据判定所有视觉细节通过。

输出位于忽略目录 `build/release-materials/screenshots/`。每张图片附有从系统读取的应用版本信息。脚本结束（包括失败退出）会尝试重建并安装正常 `lib/main.dart` 入口、清除状态栏覆盖并关闭所选模拟器；必须确认脚本与恢复步骤成功后再分发普通安装包。不要分发展示夹具。

发布截图应与最终安装包保持一致。当前发布者和支持信息未确认，所有商店材料仍是草案；没有上传商店或公开图床。
