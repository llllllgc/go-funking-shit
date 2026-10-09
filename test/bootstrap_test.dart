import 'support/reminder_fakes.dart';
import 'package:lalema/application/privacy_controller.dart';
import 'package:lalema/application/app_session.dart';
import 'support/privacy_fakes.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/bootstrap.dart';

import 'support/memory_repository.dart';

void main() {
  testWidgets('privacy initialization failure cannot reveal the log on retry', (
    tester,
  ) async {
    final store = MemoryLockStore(enabled: true)..failRead = true;
    await tester.pumpWidget(
      AppBootstrap(
        screen: FakePrivacyScreen(),
        load: () async {
          final privacy = PrivacyController(
            store: store,
            auth: FakeAuthenticator(),
            screen: FakePrivacyScreen(),
          );
          try {
            await privacy.initialize();
          } catch (_) {
            privacy.dispose();
            rethrow;
          }
          final log = BowelLogController(
            MemoryRepository(DateTime(2026, 10, 9)),
          );
          await log.initialize();
          return AppSession(
            reminders: await quietReminders(),
            log: log,
            privacy: privacy,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂时无法打开应用'), findsOneWidget);
    expect(find.byKey(const Key('today-settings')), findsNothing);
    store.failRead = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('记录已锁定'), findsOneWidget);
    expect(find.byKey(const Key('today-settings')), findsNothing);
    await tester.tap(find.byKey(const Key('privacy-unlock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-settings')), findsOneWidget);
  });

  testWidgets(
    'failed startup offers retry and eventually loads existing records',
    (tester) async {
      var attempts = 0;
      final repository = MemoryRepository(DateTime(2026, 10, 9));
      await repository.create(4);
      await tester.pumpWidget(
        AppBootstrap(
          screen: FakePrivacyScreen(),
          load: () async {
            attempts++;
            if (attempts == 1) throw StateError('open failed');
            final controller = BowelLogController(repository);
            await controller.initialize();
            return AppSession(
              reminders: await quietReminders(),
              log: controller,
              privacy: await unlockedPrivacy(),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂时无法打开应用'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('暂时无法打开应用'), findsNothing);
      expect(repository.records, hasLength(1));
    },
  );

  testWidgets('pending startup paints a loading state and handles disposal', (
    tester,
  ) async {
    final gate = Completer<AppSession>();
    await tester.pumpWidget(
      AppBootstrap(screen: FakePrivacyScreen(), load: () => gate.future),
    );
    await tester.pump();
    expect(find.text('正在打开本机记录…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final controller = BowelLogController(
      MemoryRepository(DateTime(2026, 10, 9)),
    );
    await controller.initialize();
    gate.complete(
      AppSession(
        reminders: await quietReminders(),
        log: controller,
        privacy: await unlockedPrivacy(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
