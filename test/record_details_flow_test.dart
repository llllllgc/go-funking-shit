import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/domain/record_details.dart';
import 'package:lalema/screens/record_screen.dart';

import 'support/memory_repository.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final now = DateTime(2026, 10, 9, 11, 20);
  late MemoryRepository repository;
  late BowelLogController controller;

  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(375, 812),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository = MemoryRepository(now);
    controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fillDetails(WidgetTester tester) async {
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('添加细节（可选）'));
    await tapVisible(tester, find.byKey(const ValueKey('discomfort-pain')));
    await tester.enterText(
      find.byKey(const PageStorageKey('record-note')),
      '早餐后，感觉腹胀',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('光滑柔软'));
  }

  testWidgets(
    'optional details are explicit, retryable, editable and recoverable',
    (tester) async {
      await launch(tester);
      await fillDetails(tester);
      expect(controller.records, isEmpty);
      expect(find.text('保存记录'), findsOneWidget);
      repository.failWrites = true;
      await tapVisible(tester, find.byKey(const Key('record-save')));
      expect(find.text('没有保存成功，请再试一次'), findsOneWidget);
      expect(controller.records, isEmpty);
      repository.failWrites = false;
      await tapVisible(tester, find.byKey(const Key('record-save')));
      expect(find.byType(RecordScreen), findsNothing);
      expect(controller.records.single.details.note, '早餐后，感觉腹胀');
      expect(
        controller.records.single.details.contains(Discomfort.pain),
        isTrue,
      );
      final originalId = controller.records.single.recordId;

      await tapVisible(tester, find.text('修改'));
      expect(
        tester
            .widget<TextField>(find.byKey(const PageStorageKey('record-note')))
            .controller!
            .text,
        '早餐后，感觉腹胀',
      );
      await tester.enterText(
        find.byKey(const PageStorageKey('record-note')),
        '修改后的备注',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('record-save')));
      expect(controller.records.single.recordId, originalId);
      expect(controller.records.single.details.note, '修改后的备注');
      await tapVisible(tester, find.text('历史'));
      expect(find.text('修改后的备注'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('删除这条记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复记录'));
      await tester.pumpAndSettle();
      expect(controller.records.single.recordId, originalId);
      expect(controller.records.single.details.note, '修改后的备注');
    },
  );

  testWidgets('back protects a draft and quick repeat does not copy symptoms', (
    tester,
  ) async {
    await launch(tester);
    await fillDetails(tester);
    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的细节？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(controller.records, isEmpty);
    await tapVisible(tester, find.byKey(const Key('record-save')));
    await tapVisible(tester, find.text('按上次形态记录 4型'));
    expect(controller.records, hasLength(2));
    expect(controller.records.where((r) => r.details.isEmpty), hasLength(1));
    expect(controller.records.every((r) => r.recordedAt == now), isTrue);
  });

  for (final configuration in [
    (const Size(320, 640), 2.0),
    (const Size(812, 375), 1.0),
  ]) {
    testWidgets(
      'details and observation fit ${configuration.$1} scale ${configuration.$2}',
      (tester) async {
        await launch(tester, size: configuration.$1, scale: configuration.$2);
        await tapVisible(tester, find.text('30天'));
        expect(tester.takeException(), isNull);
        await fillDetails(tester);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.byKey(const Key('record-save')));
        await tapVisible(tester, find.text('历史'));
        expect(find.text('早餐后，感觉腹胀'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
