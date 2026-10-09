import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/record_details.dart';

import 'support/memory_repository.dart';
import 'support/privacy_fakes.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final now = DateTime(2026, 10, 9, 12);
  final original = BowelRecord(
    recordId: 'recovery-original',
    bristolType: 4,
    recordedAt: now,
    updatedAt: now,
    details: const RecordDetails(note: '合成记录', discomfortMask: 5),
  );
  late MemoryRepository repository;
  late BowelLogController controller;

  Future<void> launch(
    WidgetTester tester, {
    double scale = 1,
    bool deleteImmediately = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = scale > 1
        ? const Size(320, 640)
        : const Size(375, 812);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository = MemoryRepository(now)..records.add(original);
    controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    final privacy = await unlockedPrivacy();
    await tester.pumpWidget(
      LaLeMaApp(controller: controller, privacy: privacy),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除'));
    await tester.pumpAndSettle();
    if (deleteImmediately) {
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(controller.records, isEmpty);
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      privacy.dispose();
    });
  }

  testWidgets(
    'recovery persists, retries failure and prevents duplicate writes',
    (tester) async {
      await launch(tester);
      await tester.pump(const Duration(minutes: 2));
      expect(find.text('恢复记录'), findsOneWidget);
      repository.failWrites = true;
      await tester.tap(find.byKey(const Key('undo-restore')));
      await tester.pumpAndSettle();
      expect(find.text('没有恢复成功，仍可重试'), findsOneWidget);
      expect(find.text('重试恢复'), findsOneWidget);
      expect(
        controller.deletedRecord(original.recordId)!.toMap(),
        original.toMap(),
      );
      expect(repository.records, isEmpty);
      await tester.pump(const Duration(minutes: 2));
      expect(find.text('重试恢复'), findsOneWidget);

      repository.failWrites = false;
      repository.writeGate = Completer<void>();
      await tester.tap(find.byKey(const Key('undo-restore')));
      await tester.tap(find.byKey(const Key('undo-restore')));
      await tester.pump();
      expect(repository.restoreCalls, 2); // First failure plus one retry.
      expect(find.text('正在恢复记录…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('undo-dismiss')))
            .onPressed,
        isNull,
      );
      repository.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(controller.records.single.toMap(), original.toMap());
      expect(repository.records.single.toMap(), original.toMap());
      expect(controller.deletedRecord(original.recordId), isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing a failed recovery releases the only recovery copy', (
    tester,
  ) async {
    await launch(tester);
    repository.failWrites = true;
    await tester.tap(find.byKey(const Key('undo-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('undo-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(controller.deletedRecord(original.recordId), isNull);
    expect(controller.errorMessage, isNull);
    repository.failWrites = false;
    expect(await controller.restoreRecord(original.recordId), isFalse);
    expect(repository.records, isEmpty);
  });

  testWidgets(
    'navigation during a pending restore never revives an old prompt',
    (tester) async {
      await launch(tester);
      repository.writeGate = Completer<void>();
      repository.failWrites = true;
      await tester.tap(find.byKey(const Key('undo-restore')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('today-settings')));
      await tester.tap(find.byKey(const Key('today-settings')));
      await tester.pumpAndSettle();
      expect(find.text('设置与隐私'), findsOneWidget);
      repository.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(controller.deletedRecord(original.recordId), isNull);
      expect(repository.records, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recovery and retry fit 320px with double text size', (
    tester,
  ) async {
    await launch(tester, scale: 2);
    expect(tester.takeException(), isNull);
    repository.failWrites = true;
    await tester.tap(find.byKey(const Key('undo-restore')));
    await tester.pumpAndSettle();
    expect(find.text('重试恢复'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.failWrites = false;
    await tester.tap(find.byKey(const Key('undo-restore')));
    await tester.pumpAndSettle();
    expect(controller.records.single.toMap(), original.toMap());
    expect(tester.takeException(), isNull);
  });

  testWidgets('late deletion does not show recovery on an unrelated route', (
    tester,
  ) async {
    await launch(tester, deleteImmediately: false);
    repository.writeGate = Completer<void>();
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('today-settings')));
    await tester.tap(find.byKey(const Key('today-settings')));
    await tester.pumpAndSettle();
    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('设置与隐私'), findsOneWidget);
    expect(controller.records, isEmpty);
    expect(controller.deletedRecord(original.recordId), isNull);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching tabs dismisses recovery without retaining a hidden copy',
    (tester) async {
      await launch(tester);
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(controller.deletedRecord(original.recordId), isNull);
      expect(repository.records, isEmpty);
    },
  );
}
