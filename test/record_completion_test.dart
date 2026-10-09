import 'support/reminder_fakes.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';

import 'support/memory_repository.dart';
import 'support/privacy_fakes.dart';

void main() {
  testWidgets('two taps before the save page pops still create one record', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 9, 14, 32);
    final controller = BowelLogController(
      MemoryRepository(now),
      now: () => now,
    );
    await controller.initialize();
    await tester.pumpWidget(
      LaLeMaApp(
        reminders: await quietReminders(),
        controller: controller,
        privacy: await unlockedPrivacy(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('光滑柔软'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('光滑柔软'));
    await tester.tap(find.text('光滑柔软'));
    await tester.pumpAndSettle();
    expect(controller.records, hasLength(1));
    expect(find.byKey(const Key('today-settings')), findsOneWidget);
  });

  testWidgets('slow completion reports the persisted time, not callback time', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 9, 14, 32);
    final repository = MemoryRepository(now)..writeGate = Completer<void>();
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(
      LaLeMaApp(
        reminders: await quietReminders(),
        controller: controller,
        privacy: await unlockedPrivacy(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('光滑柔软'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('光滑柔软'));
    await tester.pump();
    now = DateTime(2026, 10, 9, 16, 45);
    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(controller.records.single.recordedAt, DateTime(2026, 10, 9, 14, 32));
    expect(find.text('已保存 14:32'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
