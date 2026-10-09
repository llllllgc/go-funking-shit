import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/bootstrap.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets(
    'failed startup offers retry and eventually loads existing records',
    (tester) async {
      var attempts = 0;
      final repository = MemoryRepository(DateTime(2026, 10, 9));
      await repository.create(4);
      await tester.pumpWidget(
        AppBootstrap(
          load: () async {
            attempts++;
            if (attempts == 1) throw StateError('open failed');
            final controller = BowelLogController(repository);
            await controller.initialize();
            return controller;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂时无法读取记录'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('暂时无法读取记录'), findsNothing);
      expect(repository.records, hasLength(1));
    },
  );

  testWidgets('pending startup paints a loading state and handles disposal', (
    tester,
  ) async {
    final gate = Completer<BowelLogController>();
    await tester.pumpWidget(AppBootstrap(load: () => gate.future));
    await tester.pump();
    expect(find.text('正在打开本机记录…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final controller = BowelLogController(
      MemoryRepository(DateTime(2026, 10, 9)),
    );
    await controller.initialize();
    gate.complete(controller);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
