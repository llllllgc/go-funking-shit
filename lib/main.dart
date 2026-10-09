import 'package:flutter/widgets.dart';

import 'application/bowel_log_controller.dart';
import 'bootstrap.dart';
import 'data/sqlite_bowel_record_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppBootstrap(load: _loadRecords));
}

Future<BowelLogController> _loadRecords() async {
  final repository = await SqliteBowelRecordRepository.open();
  final controller = BowelLogController(
    repository,
    onDispose: repository.close,
  );
  await controller.initialize();
  if (!controller.hasLoaded) {
    controller.dispose();
    throw StateError('Unable to load local records');
  }
  return controller;
}
