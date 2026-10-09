import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/core/theme/app_theme.dart';
import 'package:lalema/data/knowledge_base.dart';
import 'package:lalema/data/source_links.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/knowledge_tip.dart';
import 'package:lalema/screens/knowledge_screen.dart';

import 'support/memory_repository.dart';
import 'support/privacy_fakes.dart';
import 'support/reminder_fakes.dart';

class _Links implements SourceLinks {
  final opened = <String>[];
  bool succeeds = false;
  bool throwsError = false;
  @override
  Future<bool> open(KnowledgeSource source) async {
    opened.add(source.url);
    if (throwsError) throw StateError('No browser');
    return succeeds;
  }
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final now = DateTime(2026, 10, 9, 12);
  Future<BowelLogController> log() async {
    final repository = MemoryRepository(now)
      ..records.add(
        BowelRecord(
          recordId: 'yesterday',
          bristolType: 2,
          recordedAt: now.subtract(const Duration(days: 1)),
          updatedAt: now,
        ),
      );
    final controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    return controller;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'home links the latest shape to observation rather than diet advice',
    (tester) async {
      final controller = await log();
      await tester.pumpWidget(
        LaLeMaApp(
          controller: controller,
          privacy: await unlockedPrivacy(),
          reminders: await quietReminders(),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.todayRecordCount, 0);
      expect(find.text('形态偏硬，也记下是否费力'), findsOneWidget);
      expect(find.text('纤维可以慢慢增加'), findsNothing);
      await tap(tester, find.byKey(const Key('knowledge-preview')));
      expect(find.text('形态相关纸条'), findsOneWidget);
      await tap(tester, find.byKey(const Key('knowledge-featured-open')));
      expect(find.text('参考来源'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('source-open-nhs-bristol')),
        findsOneWidget,
      );
      // The shortcut has scrolled to the actual expanded article, not just a duplicate preview.
      expect(
        tester
            .getRect(find.byKey(const Key('knowledge-card-bristol-firm')))
            .top,
        greaterThanOrEqualTo(0),
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('sources stay readable and retryable at 320px / $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final controller = await log();
      final links = _Links()..throwsError = true;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: KnowledgeScreen(controller: controller, links: links),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('knowledge-featured-open')));
      expect(
        find.bySemanticsLabel('· 便秘评估还要结合次数和症状，单次形态不能独立判断。'),
        findsOneWidget,
      );
      await tap(tester, find.byKey(const ValueKey('source-open-nhs-bristol')));
      expect(links.opened, [KnowledgeBase.bristol.url]);
      expect(find.text('未能打开浏览器。可以复制链接后自行打开。'), findsOneWidget);
      expect(find.text('参考来源'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('source-copy-nhs-bristol')));
      expect(copied, KnowledgeBase.bristol.url);
      expect(find.text('来源链接已复制'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      links.throwsError = false;
      links.succeeds = true;
      await tap(tester, find.byKey(const ValueKey('source-open-nhs-bristol')));
      expect(links.opened, hasLength(2));
      // Clicking a nested source action must not collapse the educational content.
      expect(find.text('参考来源'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets(
    'help shortcut exposes urgent guidance and sources without horizontal scrolling',
    (tester) async {
      final controller = await log();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: KnowledgeScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('knowledge-help')));
      expect(
        find.byKey(const ValueKey('knowledge-card-urgent-help')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('source-open-nhs-bleeding')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('knowledge-card-red-flag')),
        findsOneWidget,
      );
      await tap(tester, find.byKey(const ValueKey('knowledge-category-food')));
      expect(
        find.byKey(const ValueKey('knowledge-card-food-pattern')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('knowledge-card-red-flag')),
        findsNothing,
      );
      expect(find.text('参考来源'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
