import 'package:flutter/material.dart';

import '../application/bowel_log_controller.dart';
import '../core/formatters.dart';
import '../domain/bowel_record.dart';

/// Shows a short-lived recovery action after a record has been deleted.
///
/// The record remains in the controller's undo buffer until it is restored or
/// the app is restarted. Keeping the action here gives the home and history
/// screens identical feedback without coupling either screen to repository
/// details.
void showRecordUndoSnackBar(
  BuildContext context,
  BowelLogController controller,
  BowelRecord record,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('已删除 ${formatDeleteDate(record.recordedAt)}'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            controller.restoreRecord(record.recordId);
          },
        ),
      ),
    );
}
