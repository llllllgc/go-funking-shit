import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/data/knowledge_base.dart';
import 'package:lalema/domain/bowel_record.dart';

import 'support/memory_repository.dart';

void main() {
  test(
    'watery records feature hydration guidance without changing hard-stool guidance',
    () {
      expect(KnowledgeBase.featuredFor(7).id, 'loose-hydration');
      expect(KnowledgeBase.featuredFor(6).id, 'loose-hydration');
      expect(KnowledgeBase.featuredFor(2).id, 'fiber-water');
      expect(KnowledgeBase.featuredFor(4).id, 'bristol-middle');
    },
  );

  testWidgets('home paper opens the offline knowledge base', (tester) async {
    final now = DateTime(2026, 9, 19, 14, 32);
    final repository = MemoryRepository(now)
      ..records.add(
        BowelRecord(
          recordId: 'seed',
          bristolType: 2,
          recordedAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now,
        ),
      );
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();

    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('knowledge-preview')));
    await tester.tap(find.byKey(const Key('knowledge-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('knowledge-back')), findsOneWidget);
    expect(find.text('今天这张'), findsOneWidget);
    expect(find.text('纤维要慢慢加，水要跟上'), findsNWidgets(2));
    expect(find.byKey(const Key('knowledge-card-fiber-water')), findsOneWidget);

    await tester.tap(find.byKey(const Key('knowledge-card-fiber-water')));
    await tester.pumpAndSettle();
    expect(find.text('参考：美国国立糖尿病、消化和肾脏疾病研究所（NIDDK）'), findsOneWidget);

    await tester.tap(find.text('吃什么').first);
    await tester.pumpAndSettle();
    expect(find.text('食物影响，先记“自己的规律”'), findsOneWidget);
  });
}
