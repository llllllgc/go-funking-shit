import 'dart:async';

import 'bowel_log_controller.dart';
import 'privacy_controller.dart';
import 'reminder_controller.dart';

class AppSession {
  AppSession({
    required this.log,
    required this.privacy,
    required this.reminders,
    this.close,
  });
  final BowelLogController log;
  final PrivacyController privacy;
  final ReminderController reminders;
  final Future<void> Function()? close;
  void dispose() {
    log.dispose();
    privacy.dispose();
    reminders.dispose();
    if (close != null) unawaited(close!());
  }
}
