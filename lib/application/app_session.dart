import 'dart:async';

import 'bowel_log_controller.dart';
import 'privacy_controller.dart';

class AppSession {
  AppSession({required this.log, required this.privacy, this.close});
  final BowelLogController log;
  final PrivacyController privacy;
  final Future<void> Function()? close;
  void dispose() {
    log.dispose();
    privacy.dispose();
    if (close != null) unawaited(close!());
  }
}
