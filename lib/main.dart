import 'package:flutter/widgets.dart';

import 'application/bowel_log_controller.dart';
import 'bootstrap.dart';
import 'data/sqlite_bowel_record_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap(
      load: () async {
        final repository = await SqliteBowelRecordRepository.open();
        final controller = BowelLogController(repository);
        if (await controller.initialize()) return controller;
        controller.dispose();
        await repository.close();
        throw StateError('Unable to read local records');
      },
    ),
  );
}
