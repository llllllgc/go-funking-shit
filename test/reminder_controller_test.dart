import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/reminder_controller.dart';
import 'package:lalema/data/reminder_service.dart';
import 'support/reminder_fakes.dart';

void main() {
  late FakeReminderService service;
  late ReminderController controller;
  setUp(() {
    service = FakeReminderService();
    controller = ReminderController(service);
  });
  tearDown(() => controller.dispose());

  test(
    'startup stays off without asking permission; time can be saved while off',
    () async {
      await controller.refresh();
      expect(controller.state!.enabled, isFalse);
      expect(service.requests, 0);
      await controller.setTime(8, 15);
      expect(controller.state!.hour, 8);
      expect(service.enabled, isFalse);
      expect(service.requests, 0);
    },
  );

  test(
    'denied permission does not enable or schedule and allows retry',
    () async {
      service.requestedPermission = ReminderPermission.denied;
      await controller.refresh();
      await controller.setEnabled(true);
      expect(controller.state!.enabled, isFalse);
      expect(service.configurations, 0);
      await controller.openSettings();
      expect(service.settingsOpened, 1);
      service.permission = ReminderPermission.allowed;
      await controller.refresh();
      await controller.setEnabled(true);
      expect(controller.state!.scheduled, isTrue);
      await controller.setEnabled(false);
      expect(controller.state!.enabled, isFalse);
      expect(controller.state!.scheduled, isFalse);
    },
  );

  test(
    'permission dialog prevents repeated calls and rejects a locked continuation',
    () async {
      var allowed = true;
      controller.dispose();
      controller = ReminderController(service, canInteract: () => allowed);
      await controller.refresh();
      service.gate = Completer<void>();
      final pending = controller.setEnabled(true);
      await controller.setEnabled(true);
      expect(service.requests, 1);
      allowed = false;
      service.gate!.complete();
      await pending;
      expect(service.enabled, isFalse);
      expect(service.configurations, 0);
      allowed = true;
      await controller.setEnabled(true);
      expect(service.enabled, isTrue);
    },
  );

  test('ambiguous writes require read-back before another edit', () async {
    service.permission = ReminderPermission.allowed;
    await controller.refresh();
    service.failAfterCommit = true;
    await controller.setEnabled(true);
    expect(controller.uncertain, isTrue);
    expect(service.enabled, isTrue);
    await controller.setTime(9, 10);
    expect(service.configurations, 1);
    service.failAfterCommit = false;
    await controller.refresh();
    expect(controller.uncertain, isFalse);
    expect(controller.state!.enabled, isTrue);
    await controller.setEnabled(false);
    expect(service.enabled, isFalse);
  });

  test(
    'read failure is retryable, and revoked permissions do not claim scheduled',
    () async {
      service.failRead = true;
      await controller.refresh();
      expect(controller.state, isNull);
      expect(controller.message, isNotNull);
      service.failRead = false;
      service.enabled = true;
      service.permission = ReminderPermission.denied;
      await controller.refresh();
      expect(controller.state!.enabled, isTrue);
      expect(controller.state!.scheduled, isFalse);
      expect(service.requests, 0);
      await controller.setEnabled(false);
      expect(service.enabled, isFalse);
    },
  );

  test(
    'test notification is opt-in and does not change daily preference',
    () async {
      await controller.refresh();
      await controller.sendTest();
      expect(service.testsSent, 0);
      service.permission = ReminderPermission.allowed;
      await controller.refresh();
      await controller.sendTest();
      expect(service.testsSent, 1);
      expect(service.enabled, isFalse);
      expect(service.requests, 0);
    },
  );

  test(
    'native state rejects missing or invalid fields instead of guessing',
    () {
      final map = <Object?, Object?>{
        'enabled': false,
        'hour': 20,
        'minute': 0,
        'permission': 'notDetermined',
        'scheduled': false,
      };
      expect(ReminderState.fromMap(map).enabled, isFalse);
      for (final invalid in [
        <Object?, Object?>{},
        {...map, 'hour': 24},
        {...map, 'minute': -1},
        {...map, 'permission': 'unknown'},
      ]) {
        expect(() => ReminderState.fromMap(invalid), throwsFormatException);
      }
    },
  );

  test('disposed permission requests never schedule a new reminder', () async {
    await controller.refresh();
    service.gate = Completer<void>();
    final pending = controller.setEnabled(true);
    controller.dispose();
    service.gate!.complete();
    await pending;
    expect(service.configurations, 0);
    controller = ReminderController(service);
  });
}
