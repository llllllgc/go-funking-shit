# 发布签名与当前交付边界

## Android

Debug 构建用于开发和测试。Release 从 `android/key.properties` 读取独立签名配置，不再使用 Debug 密钥。

1. 由应用所有者选择或准备发布密钥。更新已发布应用时必须遵循原签名与分发渠道的密钥规则，不能随意换一把密钥。
2. 复制 `android/key.properties.example` 为 `android/key.properties`，填写 `storeFile` 的绝对路径、`storePassword`、`keyAlias`、`keyPassword`。
3. 运行 `flutter build apk --release`，或按目标分发渠道构建 App Bundle。
4. 校验产物签名、版本，并在隔离测试设备上完成安装/升级与记录保留测试，再进入分发审批。

`key.properties`、`*.jks`、`*.keystore` 都在 Git 忽略规则内。不要把实际密钥或密码写进文档、提交、PR、CI 日志。

缺失配置或密钥文件不存在时，`:app:verifyReleaseSigning` 会拒绝构建。`preReleaseBuild` 依赖该检查，因此 APK 和 App Bundle 的 Release 流程都会经过它。配置完整不代表密码/别名必然正确，后续签名任务仍会验证它们。

在**没有发布凭据的干净 checkout** 中，可用 `bash tool/check_release_signing.sh` 验证缺失配置不会意外构建出 Release。该脚本必须同时看到签名验证任务失败与预期的签名提示才报告通过；网络或编译失败不能冒充签名保护成功。

## iOS

`flutter build ios --release --no-codesign` 只证明 Release 代码可编译，不是可直接安装或上架的产物。需要应用所有者确认分发渠道与对应签名配置后，另外验证签名、安装、升级和真实文件提供者流程。

## 当前状态

- 已建立 Android 独立发布签名配置，并验证缺失配置时拒绝 Release。
- 已完成调试和未签名 iOS 构建验证，具体版本以 `release-readiness.md` 为准。
- 尚未使用正式发布密钥或进行商店提交，不自动合并 PR 或发布应用。


## 应用标识与发布主体

当前 Android applicationId / iOS Bundle ID 为 `com.lalema.lalema`。正式分发前需由发布者确认这一标识的注册与使用安排，并与既有版本的签名保持一致。另行分发 fork 时，不应在没有迁移计划的情况下随意改变已有安装的标识或签名。

发布者信息集中在 `assets/content/publishing.json`；公开政策与支持页面需实际验证可访问性，填写字段本身不等于通过审核。
