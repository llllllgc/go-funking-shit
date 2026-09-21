import 'package:flutter/widgets.dart';

import 'app.dart';
import 'application/bowel_log_controller.dart';
import 'data/sqlite_bowel_record_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await SqliteBowelRecordRepository.open();
  final controller = BowelLogController(repository);
  await controller.initialize();
  runApp(LaLeMaApp(controller: controller));
}
