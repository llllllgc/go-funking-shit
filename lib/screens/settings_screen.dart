import 'package:flutter/material.dart';

import '../application/privacy_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.privacy,
    required this.onData,
    super.key,
  });
  final PrivacyController privacy;
  final VoidCallback onData;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: privacy,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('设置与隐私', style: pixelStyle(size: 20))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('你的记录，留在你的掌握中', style: pixelStyle(size: 24, height: 1.4)),
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const Key('settings-app-lock'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('应用锁'),
                  subtitle: const Text('重新打开或切到后台后，通过设备验证才能查看记录。'),
                  value: privacy.enabled,
                  onChanged: privacy.busy ? null : privacy.setEnabled,
                ),
                const Text(
                  '使用设备现有的面容、指纹或锁屏密码，验证由系统处理。开启后，Android 也会限制应用截图和投屏。',
                  style: TextStyle(color: AppColors.inkMuted, height: 1.5),
                ),
                if (privacy.message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        privacy.message!,
                        key: const Key('privacy-feedback'),
                      ),
                    ),
                  ),
                if (privacy.busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                if (privacy.enabled)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('settings-lock-now'),
                      onPressed: privacy.busy ? null : privacy.lock,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('立即锁定'),
                    ),
                  ),
                const Divider(height: 40),
                Text('数据与备份', style: pixelStyle(size: 20)),
                const SizedBox(height: 12),
                const Text(
                  '应用锁只限制应用内查看，不会加密记录文件、导出文件或系统备份。请保管好设备密码和备份；设备验证无法使用时，需要先恢复验证能力。',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('settings-data'),
                  onPressed: privacy.busy ? null : onData,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('备份、导出与恢复'),
                ),
                const Divider(height: 40),
                Text('隐私说明', style: pixelStyle(size: 20)),
                const SizedBox(height: 12),
                const Text(
                  '本应用不要求账号，不向自有服务器上传记录，也不包含广告或行为分析。记录保存在设备的应用数据中，卸载可能删除这些数据。',
                ),
                const SizedBox(height: 12),
                const Text(
                  '设备备份可能包含应用数据，取决于系统设置。选择云盘导出时，文件由你选择的服务保管。JSON 和 CSV 导出文件未加密，请妥善保存。',
                ),
                const SizedBox(height: 12),
                const Text(
                  '应用不读取或保存系统验证的密码、指纹或面容数据。应用锁不能抵御设备被破解或其他人掌握设备解锁凭据的情况。',
                  style: TextStyle(color: AppColors.inkMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
