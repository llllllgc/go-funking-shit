import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/domain/bowel_record.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('history filters by visible code, type, and date', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 12, 12);
    final repository = MemoryRepository(now);
    repository.records.addAll([
      BowelRecord(
        recordId: 'soft',
        bristolType: 4,
        recordedAt: DateTime(2026, 10, 12, 9),
        updatedAt: now,
      ),
      BowelRecord(
        recordId: 'hard',
        bristolType: 1,
        recordedAt: DateTime(2026, 10, 1, 9),
        updatedAt: now,
      ),
    ]);
    final controller = BowelLogController(repository, now: () => now);
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-result-count')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('history-search')), '01 光滑柔软');
    await tester.pumpAndSettle();
    expect(find.text('找到 1 条 / 全部 2 条'), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('近 7 天'));
    await tester.pumpAndSettle();
    expect(find.text('找到 1 条 / 全部 2 条'), findsOneWidget);

    await tester.tap(find.text('按形态筛选'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('history-type-1')));
    await tester.tap(find.byKey(const ValueKey('history-type-1')));
    await tester.pumpAndSettle();
    expect(find.text('找到 0 条 / 全部 2 条'), findsOneWidget);
    expect(find.text('没有符合条件的记录'), findsOneWidget);
  });
}
