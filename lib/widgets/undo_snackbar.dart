import 'package:flutter/material.dart';

import '../application/bowel_log_controller.dart';
import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../domain/bowel_record.dart';

/// Keeps the recovery action available until the user restores the record or
/// dismisses the prompt. A failed write leaves the same prompt retryable.
/// Dismissal releases the in-memory copy; this is not a persistent trash bin.
void showRecordUndoSnackBar(
  BuildContext context,
  BowelLogController controller,
  BowelRecord record,
) {
  final recovery = controller.recoveryFor(record.recordId);
  if (recovery == null) return;
  if (ModalRoute.of(context)?.isCurrent == false) {
    controller.dismissRecovery(recovery);
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    controller.dismissRecovery(recovery);
    return;
  }
  messenger.removeCurrentSnackBar();
  var closed = false;
  late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> prompt;
  prompt = messenger.showSnackBar(
    SnackBar(
      persist: true,
      // Closing during a write is handled by navigation/ownership checks,
      // rather than an accidental swipe while the action is still pending.
      dismissDirection: DismissDirection.none,
      backgroundColor: AppColors.ink,
      content: _RecoveryPrompt(
        controller: controller,
        recovery: recovery,
        onClose: () {
          if (!closed && messenger.mounted) prompt.close();
        },
      ),
    ),
  );
  prompt.closed.then((_) {
    closed = true;
    controller.dismissRecovery(recovery);
  });
}

class _RecoveryPrompt extends StatefulWidget {
  const _RecoveryPrompt({
    required this.controller,
    required this.recovery,
    required this.onClose,
  });

  final BowelLogController controller;
  final RecordRecovery recovery;
  final VoidCallback onClose;

  @override
  State<_RecoveryPrompt> createState() => _RecoveryPromptState();
}

class _RecoveryPromptState extends State<_RecoveryPrompt> {
  bool _restoring = false;
  bool _failed = false;

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final restored = await widget.controller.restoreRecord(
      widget.recovery.record.recordId,
      expectedRecovery: widget.recovery,
    );
    if (!mounted) return;
    if (restored ||
        !identical(
          widget.controller.recoveryFor(widget.recovery.record.recordId),
          widget.recovery,
        )) {
      widget.onClose();
      return;
    }
    setState(() {
      _restoring = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final busy = _restoring || widget.controller.isWorking;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              _restoring
                  ? '正在恢复记录…'
                  : _failed
                  ? '没有恢复成功，仍可重试'
                  : '已删除 ${formatDeleteDate(widget.recovery.record.recordedAt)}',
              style: const TextStyle(color: AppColors.paper, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '关闭提示、离开此页或退出应用后无法恢复。',
            style: TextStyle(color: AppColors.paper, fontSize: 12, height: 1.5),
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                key: const Key('undo-restore'),
                onPressed: busy ? null : _restore,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mustard,
                  disabledForegroundColor: AppColors.rule,
                ),
                child: Text(_failed ? '重试恢复' : '恢复记录'),
              ),
              TextButton(
                key: const Key('undo-dismiss'),
                onPressed: busy ? null : widget.onClose,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.paper,
                  disabledForegroundColor: AppColors.rule,
                ),
                child: const Text('关闭提示'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
