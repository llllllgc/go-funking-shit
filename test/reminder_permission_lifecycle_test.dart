import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/privacy_controller.dart';
import 'package:lalema/application/reminder_controller.dart';

import 'support/privacy_fakes.dart';
import 'support/reminder_fakes.dart';

void main() {
  late PrivacyController privacy;
  late ReminderController reminders;
  late FakeReminderService service;
  var privacyDisposed = false;

  setUp(() async {
    privacyDisposed = false;
    privacy = await unlockedPrivacy();
    service = FakeReminderService()..gate = Completer<void>();
    reminders = ReminderController(
      service,
      canInteract: () => privacy.allowsInteraction(privacy.accessEpoch),
      interactionEpoch: () => privacy.accessEpoch,
      waitForInteraction: privacy.waitForInteraction,
    );
    await reminders.refresh();
  });

  tearDown(() {
    reminders.dispose();
    if (!privacyDisposed) privacy.dispose();
  });

  Future<void> permissionReturns() async {
    service.gate!.complete();
    // Let the permission continuation run while the lifecycle is still inactive.
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'permission before resume waits and enables once in the same session',
    () async {
      final enabling = reminders.setEnabled(true);
      privacy.lifecycleChanged(AppLifecycleState.inactive);
      await permissionReturns();
      expect(reminders.busy, isTrue);
      expect(service.configurations, 0);
      await reminders.setEnabled(true);
      await reminders.refresh(); // The normal resume refresh may be queued too.
      privacy.lifecycleChanged(AppLifecycleState.resumed);
      await enabling;
      await Future<void>.delayed(Duration.zero);
      expect(service.requests, 1);
      expect(service.configurations, 1);
      expect(reminders.state!.scheduled, isTrue);
    },
  );

  test('permission after resume also enables without a second tap', () async {
    final enabling = reminders.setEnabled(true);
    privacy.lifecycleChanged(AppLifecycleState.inactive);
    privacy.lifecycleChanged(AppLifecycleState.resumed);
    await permissionReturns();
    await enabling;
    expect(service.configurations, 1);
    expect(reminders.state!.scheduled, isTrue);
  });

  test(
    'background before permission returns invalidates the old request',
    () async {
      final enabling = reminders.setEnabled(true);
      privacy.lifecycleChanged(AppLifecycleState.inactive);
      privacy.lifecycleChanged(AppLifecycleState.hidden);
      privacy.lifecycleChanged(AppLifecycleState.paused);
      privacy.lifecycleChanged(AppLifecycleState.resumed);
      expect(privacy.concealed, isFalse);
      await permissionReturns();
      await enabling;
      expect(service.configurations, 0);
      expect(service.enabled, isFalse);
    },
  );

  test(
    'background while awaiting resume cancels instead of enabling later',
    () async {
      final enabling = reminders.setEnabled(true);
      privacy.lifecycleChanged(AppLifecycleState.inactive);
      await permissionReturns();
      expect(reminders.busy, isTrue);
      privacy.lifecycleChanged(AppLifecycleState.hidden);
      privacy.lifecycleChanged(AppLifecycleState.paused);
      privacy.lifecycleChanged(AppLifecycleState.resumed);
      await enabling;
      expect(service.configurations, 0);
      expect(reminders.busy, isFalse);
    },
  );

  test(
    'a permission dialog that relocks the app cannot auto-enable after unlock',
    () async {
      await privacy.setEnabled(true);
      final enabling = reminders.setEnabled(true);
      privacy.lifecycleChanged(AppLifecycleState.inactive);
      await permissionReturns();
      privacy.lifecycleChanged(AppLifecycleState.resumed);
      await enabling;
      expect(service.configurations, 0);
      expect(privacy.concealed, isTrue);
      await privacy.unlock();
      expect(privacy.concealed, isFalse);
      expect(service.configurations, 0);
    },
  );

  test(
    'privacy reload cancels an outstanding permission continuation',
    () async {
      final enabling = reminders.setEnabled(true);
      privacy.lifecycleChanged(AppLifecycleState.inactive);
      await permissionReturns();
      await privacy.initialize();
      privacy.lifecycleChanged(AppLifecycleState.resumed);
      await enabling;
      expect(service.configurations, 0);
    },
  );

  test(
    'disposing privacy releases the pending permission continuation',
    () async {
      final enabling = reminders.setEnabled(true);
      privacy.lifecycleChanged(AppLifecycleState.inactive);
      await permissionReturns();
      privacy.dispose();
      privacyDisposed = true;
      await enabling;
      expect(service.configurations, 0);
      expect(reminders.busy, isFalse);
    },
  );
}
