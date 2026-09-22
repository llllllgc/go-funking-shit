import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/screens/calendar_screen.dart';
import 'package:lalema/screens/record_screen.dart';
import 'package:lalema/widgets/pressable.dart';

import 'support/memory_repository.dart';

void main() {
  final now = DateTime(2026, 9, 19, 14, 32);
  late MemoryRepository repository;
  late BowelLogController controller;

  Future<void> launch(WidgetTester tester, {DateTime? clock}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    repository = MemoryRepository(clock ?? now);
    controller = BowelLogController(repository, now: () => clock ?? now);
    await controller.initialize();
    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();
  }

  Finder day(DateTime date) =>
      find.byKey(ValueKey('calendar-day-${date.toIso8601String()}'));

  testWidgets('home paper opens its exact day; today icon returns to today', (
    tester,
  ) async {
    await launch(tester);
    final yesterday = DateTime(2026, 9, 18);
    await tester.tap(
      find.byKey(ValueKey('week-day-${yesterday.toIso8601String()}')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('calendar-selected-date'))).data,
      '9月18日 周五',
    );
    expect(find.text('回今天'), findsNothing);
    expect(
      tester.widget<Pressable>(day(DateTime(2026, 9, 20))).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<Pressable>(
            find.descendant(
              of: find.byKey(const Key('calendar-next')),
              matching: find.byType(Pressable),
            ),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('calendar-today')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Pressable>(day(DateTime(2026, 9, 19))).selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('natural months handle leap day and year boundaries', (
    tester,
  ) async {
    await launch(tester, clock: DateTime(2024, 3, 31, 12));
    await tester.tap(find.byTooltip('查看月历').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-prev')));
    await tester.pumpAndSettle();
    expect(day(DateTime(2024, 2, 29)), findsOneWidget);
    expect(
      tester.widget<Pressable>(day(DateTime(2024, 2, 29))).selected,
      isTrue,
    );
    expect(
      find.byKey(
        ValueKey('calendar-day-${DateTime(2024, 3, 1).toIso8601String()}'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('calendar-prev')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-prev')));
    await tester.pumpAndSettle();
    expect(find.text('2023年12月'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history backfill saves yesterday and leaves today count unchanged',
    (tester) async {
      await launch(tester);
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-backfill')));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月18日'), findsOneWidget);
      expect(
        tester.widget<Pressable>(find.byKey(const Key('record-save'))).enabled,
        isFalse,
      );
      await tester.ensureVisible(find.text('光滑柔软'));
      await tester.tap(find.text('光滑柔软'));
      await tester.pumpAndSettle();
      expect(controller.records, isEmpty);
      await tester.tap(find.byKey(const Key('record-save')));
      await tester.pumpAndSettle();
      expect(find.byType(RecordScreen), findsNothing);
      expect(
        controller.records.single.recordedAt,
        DateTime(2026, 9, 18, 14, 32),
      );
      expect(controller.todayRecordCount, 0);
      expect(find.text('9月18日 周五'), findsOneWidget);
    },
  );

  testWidgets(
    'calendar backfill and cross-day edit keep selection and counts in sync',
    (tester) async {
      await launch(tester);
      final selected = DateTime(2026, 9, 17);
      await tester.tap(
        find.byKey(ValueKey('week-day-${selected.toIso8601String()}')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('calendar-backfill')));
      await tester.tap(find.byKey(const Key('calendar-backfill')));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月17日'), findsOneWidget);
      await tester.ensureVisible(find.text('光滑柔软'));
      await tester.tap(find.text('光滑柔软'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-save')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('calendar-selected-date')))
            .data,
        '9月17日 周四',
      );
      await tester.ensureVisible(find.text('修改'));
      await tester.tap(find.text('修改'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('今天'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-save')));
      await tester.pumpAndSettle();
      expect(controller.records, hasLength(1));
      expect(controller.recordsForDate(selected), isEmpty);
      expect(controller.todayRecordCount, 1);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('calendar-selected-date')))
            .data,
        '9月19日 周六',
      );
    },
  );

  testWidgets(
    'failed save retains chosen date and type; cancel writes nothing',
    (tester) async {
      await launch(tester);
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-backfill')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('光滑柔软'));
      await tester.tap(find.text('光滑柔软'));
      await tester.pumpAndSettle();
      repository.failWrites = true;
      await tester.tap(find.byKey(const Key('record-save')));
      await tester.pumpAndSettle();
      expect(find.text('没有保存成功，请再试一次'), findsOneWidget);
      expect(find.text('已选'), findsOneWidget);
      expect(find.text('补记到 9月18日'), findsOneWidget);
      expect(controller.records, isEmpty);
      Navigator.of(tester.element(find.byType(RecordScreen))).pop();
      await tester.pumpAndSettle();
      expect(controller.records, isEmpty);
    },
  );

  testWidgets('normal recording still saves in one tap', (tester) async {
    await launch(tester);
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-date')), findsNothing);
    await tester.ensureVisible(find.text('光滑柔软'));
    await tester.tap(find.text('光滑柔软'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordScreen), findsNothing);
    expect(controller.todayRecordCount, 1);
  });

  testWidgets('history deletion offers an undo action', (tester) async {
    await launch(tester);
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('光滑柔软'));
    await tester.tap(find.text('光滑柔软'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('删除这条记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('删除'));
    await tester.pumpAndSettle();
    expect(controller.records, isEmpty);
    expect(find.text('已删除'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(controller.records, hasLength(1));
  });

  testWidgets('year and month selection jumps to an older month', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.byTooltip('查看月历'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-month-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-year-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024年').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-month-picker')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2月'),
      -120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('2月').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(find.text('2024年2月'), findsOneWidget);
    expect(day(DateTime(2024, 2, 29)), findsOneWidget);
    expect(
      tester.widget<Pressable>(day(DateTime(2024, 2, 19))).selected,
      isTrue,
    );
  });
}
