import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/bristol_type.dart';
import 'package:lalema/widgets/pressable.dart';

import 'support/memory_repository.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final now = DateTime(2026, 9, 19, 14, 32);
  late MemoryRepository repository;
  late BowelLogController controller;

  Future<void> launch(
    WidgetTester tester, {
    double width = 375,
    bool seed = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, width == 320 ? 640 : 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    repository = MemoryRepository(now);
    if (seed) {
      repository.records.add(
        BowelRecord(
          recordId: 'seed',
          bristolType: 4,
          recordedAt: now,
          updatedAt: now,
        ),
      );
    }
    controller = BowelLogController(repository, now: () => now);
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 375.0, 414.0, 768.0]) {
    testWidgets(
      'save, undo and recover from compact feedback at ${width.toInt()}px',
      (tester) async {
        await launch(tester, width: width);
        expect(find.text('今天拉完了'), findsOneWidget);
        expect(find.text('今天暂无记录'), findsOneWidget);
        await tester.tap(find.text('记录'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('光滑柔软')).dy,
          lessThan(tester.getTopLeft(find.text('颗粒偏硬')).dy),
        );
        expect(bristolTypes.first.code, '01');
        expect(bristolTypes.first.assetPath, 'assets/icons/ic_bristol_04.svg');
        expect(bristolTypes[3].code, '04');
        expect(bristolTypes[3].assetPath, 'assets/icons/ic_bristol_01.svg');
        await tester.tap(find.text('光滑柔软'));
        await tester.pumpAndSettle();
        final original = controller.records.single;
        expect(original.bristolType, 4);
        expect(find.textContaining('01　光滑柔软'), findsOneWidget);
        expect(find.text('已记录 · 14:32'), findsOneWidget);
        await tester.tap(find.byKey(const Key('record-feedback-action')));
        await tester.pumpAndSettle();
        expect(controller.todayRecordCount, 0);
        expect(find.text('恢复'), findsOneWidget);
        await tester.tap(find.byKey(const Key('record-feedback-action')));
        await tester.pumpAndSettle();
        expect(controller.records.single.toMap(), original.toMap());
        expect(find.text('已恢复 · 14:32'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }

  testWidgets('history deletion offers recovery and timeout dismisses it', (
    tester,
  ) async {
    await launch(tester, seed: true);
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Pressable && widget.semanticLabel == '删除这条记录',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已删除'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
    expect(repository.records, isEmpty);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await controller.restoreDeletedRecord('seed');
    expect(repository.records, isEmpty);
  });
}
