import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/record_details.dart';

import 'support/memory_repository.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final now = DateTime(2026, 10, 9, 12);
  late BowelLogController controller;
  late MemoryRepository repository;
  BowelRecord record(
    String id,
    DateTime at, {
    int type = 4,
    String note = '',
    int discomfort = 0,
  }) => BowelRecord(
    recordId: id,
    bristolType: type,
    recordedAt: at,
    updatedAt: now,
    details: RecordDetails(note: note, discomfortMask: discomfort),
  );

  Future<void> launch(
    WidgetTester tester, {
    List<BowelRecord>? records,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = scale > 1
        ? const Size(320, 640)
        : const Size(375, 812);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository = MemoryRepository(now)
      ..records.addAll(
        records ??
            [
              record('today', now, note: 'Coffee 咖啡', discomfort: 2),
              record('last-week', DateTime(2026, 10, 1), note: 'COFFEE'),
              record(
                'yesterday',
                DateTime(2026, 10, 8),
                type: 2,
                note: '晚饭后',
                discomfort: 8,
              ),
              record('old', DateTime(2026, 7, 1), type: 7, note: '旅行中'),
            ],
      );
    controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
  }

  Finder historyScroll() => find
      .descendant(
        of: find.byKey(const PageStorageKey('history-list')),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> visible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 160, scrollable: historyScroll());
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await visible(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await visible(tester, find.byKey(const Key('history-search')));
    await tester.enterText(find.byKey(const Key('history-search')), text);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'today rolls over at midnight without waiting for minute polling',
    (tester) async {
      final start = tester.binding.clock.now();
      final midnightStart = DateTime(2026, 12, 31, 23, 59, 59);
      final repository = MemoryRepository(midnightStart)
        ..records.add(record('last-year', midnightStart));
      final controller = BowelLogController(
        repository,
        now: () =>
            midnightStart.add(tester.binding.clock.now().difference(start)),
      );
      await controller.initialize();
      await tester.pumpWidget(LaLeMaApp(controller: controller));
      await tester.pump();
      expect(controller.todayRecordCount, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.currentDate, DateTime(2027, 1, 1));
      expect(controller.todayRecordCount, 0);
      expect(controller.records, hasLength(1));
    },
  );

  testWidgets('foreground clock changes still refresh the current day', (
    tester,
  ) async {
    var current = DateTime(2026, 10, 9, 12);
    final controller = BowelLogController(
      MemoryRepository(current),
      now: () => current,
    );
    await controller.initialize();
    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pump();
    current = DateTime(2026, 10, 10, 12);
    await tester.pump(const Duration(minutes: 1));
    expect(controller.currentDate, DateTime(2026, 10, 10));
  });

  testWidgets('switching tabs before debounce still retains the typed query', (
    tester,
  ) async {
    await launch(tester);
    await tester.enterText(find.byKey(const Key('history-search')), 'Coffee');
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('history-search')))
          .controller!
          .text,
      'Coffee',
    );
    expect(find.text('找到 2 条 / 全部 4 条'), findsOneWidget);
  });

  testWidgets('search and range combine and survive tab switches', (
    tester,
  ) async {
    await launch(tester);
    await search(tester, 'coffee');
    expect(find.text('找到 2 条 / 全部 4 条'), findsOneWidget);
    await tap(tester, find.text('近 7 天'));
    expect(find.text('找到 1 条 / 全部 4 条'), findsOneWidget);
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('history-search')))
          .controller!
          .text,
      'coffee',
    );
    expect(find.text('找到 1 条 / 全部 4 条'), findsOneWidget);
    await tap(tester, find.byKey(const Key('history-reset')));
    expect(find.text('共 4 笔记录'), findsOneWidget);
    expect(controller.records, hasLength(4));
  });

  testWidgets(
    'type and discomfort narrow results and clear does not delete data',
    (tester) async {
      await launch(tester);
      await tap(
        tester,
        find.byKey(const PageStorageKey('history-extra-filters')),
      );
      await tap(tester, find.byKey(const ValueKey('history-type-4')));
      await tap(tester, find.byKey(const Key('history-discomfort')));
      expect(find.text('找到 1 条 / 全部 4 条'), findsOneWidget);
      await search(tester, '水样');
      expect(find.text('找到 0 条 / 全部 4 条'), findsOneWidget);
      await tap(tester, find.text('查看全部记录'));
      expect(find.text('共 4 笔记录'), findsOneWidget);
      expect(repository.records, hasLength(4));
    },
  );

  testWidgets(
    'delete and restore update a filtered list without losing criteria',
    (tester) async {
      await launch(tester);
      await search(tester, '旅行');
      await tap(tester, find.bySemanticsLabel('删除这条记录'));
      await tester.tap(find.bySemanticsLabel('删除'));
      await tester.pumpAndSettle();
      expect(find.text('找到 0 条 / 全部 3 条'), findsOneWidget);
      await tester.tap(find.text('恢复记录'));
      await tester.pumpAndSettle();
      expect(find.text('找到 1 条 / 全部 4 条'), findsOneWidget);
      expect(controller.record('old')!.details.note, '旅行中');
    },
  );

  testWidgets('custom calendar range applies both endpoints', (tester) async {
    await launch(tester);
    await tap(tester, find.byKey(const Key('history-date-range')));
    await tester.tap(find.byKey(const Key('history-range-input')));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '2026/10/01');
    await tester.enterText(fields.at(1), '2026/10/08');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.text('2026/10/1 — 2026/10/8'), findsOneWidget);
    expect(find.text('找到 2 条 / 全部 4 条'), findsOneWidget);
  });

  testWidgets('five thousand rows stay lazy while search reaches old entries', (
    tester,
  ) async {
    await launch(
      tester,
      records: List.generate(
        5000,
        (index) => record(
          'row-$index',
          now.subtract(Duration(days: index)),
          note: 'entry $index',
        ),
      ),
    );
    final rows = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('history-record-'),
    );
    expect(rows.evaluate().length, lessThan(30));
    await search(tester, 'entry 4999');
    await visible(
      tester,
      find.byKey(const ValueKey('history-record-row-4999')),
    );
    expect(find.text('找到 1 条 / 全部 5000 条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'advanced controls and filtered records support double text size',
    (tester) async {
      await launch(tester, scale: 2);
      await tap(
        tester,
        find.byKey(const PageStorageKey('history-extra-filters')),
      );
      await tap(tester, find.byKey(const Key('history-discomfort')));
      expect(find.text('找到 2 条 / 全部 4 条'), findsOneWidget);
      await visible(tester, find.byKey(const ValueKey('history-record-today')));
      expect(
        tester.getRect(find.textContaining('12:00')).height,
        greaterThan(30),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
