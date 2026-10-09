import 'package:flutter/material.dart';
import '../application/reminder_controller.dart';
import '../data/reminder_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class ReminderSettings extends StatelessWidget {
  const ReminderSettings({required this.controller, super.key});
  final ReminderController controller;

  Future<void> _chooseTime(BuildContext context) async {
    final state = controller.state;
    if (state == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.hour, minute: state.minute),
      helpText: '选择每日提醒时间',
      cancelText: '取消',
      confirmText: '保存',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null && context.mounted) {
      await controller.setTime(time.hour, time.minute);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final state = controller.state;
      final available =
          state != null && !controller.busy && !controller.uncertain;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('按自己的节奏记录', style: pixelStyle(size: 20)),
          const SizedBox(height: 8),
          const Text('提醒只为帮你记下情况，不是催促如厕。默认关闭。'),
          SwitchListTile(
            key: const Key('reminder-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('每日提醒'),
            subtitle: Text(
              controller.uncertain || state == null
                  ? '状态待确认'
                  : !state.enabled
                  ? '已关闭'
                  : state.permission != ReminderPermission.allowed
                  ? '系统通知未允许，暂时不会提醒'
                  : state.scheduled
                  ? '已安排，按设备当地时间提醒'
                  : '尚未安排，请重试',
            ),
            value: state?.enabled ?? false,
            onChanged: available ? controller.setEnabled : null,
          ),
          if (state != null)
            OutlinedButton.icon(
              key: const Key('reminder-time'),
              onPressed: available ? () => _chooseTime(context) : null,
              icon: const Icon(Icons.schedule),
              label: Text(
                '提醒时间  ${state.hour.toString().padLeft(2, '0')}:${state.minute.toString().padLeft(2, '0')}',
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            '通知只显示通用提示，不显示次数、形态或备注。系统省电或专注模式可能延后或静音通知。',
            style: TextStyle(color: AppColors.inkMuted, height: 1.5),
          ),
          if (controller.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (controller.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  controller.message!,
                  key: const Key('reminder-feedback'),
                ),
              ),
            ),
          Wrap(
            spacing: 12,
            children: [
              if (state?.enabled == true &&
                  state?.permission == ReminderPermission.notDetermined)
                TextButton(
                  key: const Key('reminder-allow'),
                  onPressed: available
                      ? () => controller.setEnabled(true)
                      : null,
                  child: const Text('允许通知'),
                ),
              if (controller.uncertain ||
                  state == null ||
                  (state.enabled && !state.scheduled))
                TextButton(
                  key: const Key('reminder-retry'),
                  onPressed: controller.busy ? null : controller.refresh,
                  child: const Text('重新检查'),
                ),
              if (state?.permission == ReminderPermission.denied)
                TextButton(
                  key: const Key('reminder-system-settings'),
                  onPressed: controller.busy ? null : controller.openSettings,
                  child: const Text('打开系统通知设置'),
                ),
              if (state?.permission == ReminderPermission.allowed)
                TextButton(
                  key: const Key('reminder-test'),
                  onPressed: controller.busy ? null : controller.sendTest,
                  child: const Text('发送测试提醒'),
                ),
            ],
          ),
        ],
      );
    },
  );
}
