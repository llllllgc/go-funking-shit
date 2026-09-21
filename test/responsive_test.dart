import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/data/bowel_record_repository.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/screens/calendar_screen.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  const sizes = <Size>[
    Size(320, 640),
    Size(375, 812),
    Size(414, 896),
    Size(768, 1024),
  ];

  for (final size in sizes) {
    testWidgets('active screens do not overflow at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime(2026, 9, 16, 14, 32);
      final controller = BowelLogController(
        _ResponsiveRepository(now),
        now: () => now,
      );
      await controller.initialize();
      await tester.pumpWidget(LaLeMaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('记录'));
      await tester.pumpAndSettle();
      expect(find.text('更接近哪一种？'), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(tester.element(find.text('更接近哪一种？'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      expect(find.text('历史'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('查看月历'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('calendar-month-title')));
      await tester.pumpAndSettle();
      expect(find.text('选择月份'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('calendar-backfill')));
      await tester.tap(find.byKey(const Key('calendar-backfill')));
      await tester.pumpAndSettle();
      expect(find.text('补记'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('record-date')));
      await tester.pumpAndSettle();
      expect(find.text('选择记录日期'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-time')));
      await tester.pumpAndSettle();
      expect(find.text('选择实际发生时间'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('水样偏稀'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('水样偏稀'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('水样偏稀'));
      await tester.pumpAndSettle();
      expect(find.text('已选'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ResponsiveRepository implements BowelRecordRepository {
  _ResponsiveRepository(DateTime now)
    : _records = List<BowelRecord>.generate(
        12,
        (index) => BowelRecord(
          recordId: 'record-$index',
          bristolType: index % 7 + 1,
          recordedAt: now.subtract(Duration(minutes: index * 8)),
          updatedAt: now,
        ),
      );

  final List<BowelRecord> _records;

  @override
  Future<BowelRecord> create(int bristolType, {DateTime? recordedAt}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String recordId) => throw UnimplementedError();

  @override
  Future<List<BowelRecord>> loadAll() async => List<BowelRecord>.of(_records);

  @override
  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
  }) => throw UnimplementedError();
}
