import 'dart:async';
import 'package:flutter/widgets.dart';

import 'application/app_session.dart';
import 'application/reminder_controller.dart';
import 'data/reminder_service.dart';
import 'application/bowel_log_controller.dart';
import 'application/privacy_controller.dart';
import 'bootstrap.dart';
import 'data/privacy_services.dart';
import 'data/sqlite_bowel_record_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppBootstrap(load: _loadSession));
}

Future<AppSession> _loadSession() async {
  final repository = await SqliteBowelRecordRepository.open();
  final privacy = PrivacyController(
    store: repository,
    auth: SystemDeviceAuthenticator(),
    screen: const NativePrivacyScreen(),
  );
  final reminders = ReminderController(
    const NativeReminderService(),
    canInteract: () => privacy.allowsInteraction(privacy.accessEpoch),
  );
  final log = BowelLogController(
    repository,
    canWrite: () => privacy.allowsInteraction(privacy.accessEpoch),
  );
  try {
    await privacy.initialize();
    await log.initialize();
    if (!log.hasLoaded) throw StateError('Unable to load local records');
    // Optional reminders must never delay access to the log.
    unawaited(reminders.refresh());
    return AppSession(
      log: log,
      privacy: privacy,
      reminders: reminders,
      close: repository.close,
    );
  } catch (_) {
    privacy.dispose();
    reminders.dispose();
    log.dispose();
    await repository.close();
    rethrow;
  }
}
