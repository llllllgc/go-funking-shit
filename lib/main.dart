import 'package:flutter/widgets.dart';

import 'application/app_session.dart';
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
  final log = BowelLogController(
    repository,
    canWrite: () => privacy.allowsInteraction(privacy.accessEpoch),
  );
  try {
    await privacy.initialize();
    await log.initialize();
    if (!log.hasLoaded) throw StateError('Unable to load local records');
    return AppSession(log: log, privacy: privacy, close: repository.close);
  } catch (_) {
    privacy.dispose();
    log.dispose();
    await repository.close();
    rethrow;
  }
}
