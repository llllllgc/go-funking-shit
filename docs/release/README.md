# 发布资料

这些文件用于审核与准备，不自动发布网站、提交商店或合并 PR。

- [隐私政策草案](privacy-policy.md) / [可托管 HTML](privacy-policy.html)
- [使用帮助](user-guide.md) / [可托管 HTML](user-guide.html)
- [版本更新](changelog.md)
- [商店文案与审核备注草案](store-listing-draft.md)
- [资源出处与分发确认](asset-provenance.md)
- [iPhone 截图草案与复现](screenshots.md)
- [完整验收状态](../release-readiness.md)

## 统一内容源

应用内说明来自 `assets/content/app_documents.json`。发布者信息来自 `assets/content/publishing.json`。修改后运行：

```sh
dart run tool/export_app_documents.dart
```

CI 用 `dart run tool/export_app_documents.dart --check` 确认网页/Markdown 与应用内容一致。不要单独编辑生成的政策、帮助和版本记录文件。

正式发布资料准备时额外运行：

```sh
dart run tool/export_app_documents.dart --check --require-publisher
```

该检查只核对文档一致性与发布者字段是否提供，不证明公开地址可访问、签名/授权有效或实机测试完成。当前发布者名称及支持联系方式仍待所有者提供，因此应明确失败；不能填入假邮箱或占位联系人来使检查通过。

将 HTML 托管或在商店填写网址前，需实际打开最终公开 URL 核对内容和匿名可访问性。GitHub 中仍标记为草案的政策不能据此声称已完成发布审批。
