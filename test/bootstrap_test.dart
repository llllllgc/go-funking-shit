import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/bootstrap.dart';

import 'support/memory_repository.dart';

void main() {
  test('failed initial read blocks writes until a successful retry', () async {
    final now = DateTime(2026, 9, 19, 12);
    final repository = MemoryRepository(now)..failReads = true;
    final controller = BowelLogController(repository, now: () => now);
    addTearDown(controller.dispose);

    expect(await controller.initialize(), isFalse);
    expect(controller.hasLoaded, isFalse);
    expect(await controller.saveType(4), isFalse);
    expect(repository.createCalls, 0);

    repository.failReads = false;
    expect(await controller.initialize(), isTrue);
    expect(await controller.saveType(4), isTrue);
    expect(repository.records, hasLength(1));
  });

  testWidgets('startup failure shows retry and opens saved records', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 19, 12);
    final repository = MemoryRepository(now);
    var attempts = 0;

    await tester.pumpWidget(
      AppBootstrap(
        load: () async {
          attempts++;
          if (attempts == 1) throw StateError('Temporary read failure');
          final controller = BowelLogController(repository, now: () => now);
          await controller.initialize();
          return controller;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂时无法打开应用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('今天拉完了'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
