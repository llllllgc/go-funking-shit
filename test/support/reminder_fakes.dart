import 'dart:async';
import 'package:lalema/application/reminder_controller.dart';
import 'package:lalema/data/reminder_service.dart';

class FakeReminderService implements ReminderService {
  bool enabled = false;
  int hour = 20;
  int minute = 0;
  ReminderPermission permission = ReminderPermission.notDetermined;
  ReminderPermission requestedPermission = ReminderPermission.allowed;
  bool failRead = false;
  bool failConfigure = false;
  bool failAfterCommit = false;
  int requests = 0;
  int configurations = 0;
  int settingsOpened = 0;
  int testsSent = 0;
  Completer<void>? gate;

  ReminderState get current => ReminderState(
    enabled: enabled,
    hour: hour,
    minute: minute,
    permission: permission,
    scheduled: enabled && permission == ReminderPermission.allowed,
    nextAt: enabled && permission == ReminderPermission.allowed
        ? DateTime(2026, 10, 10, hour, minute)
        : null,
  );

  @override
  Future<ReminderState> read() async {
    if (failRead) throw StateError('read failed');
    return current;
  }

  @override
  Future<ReminderState> requestPermission() async {
    requests++;
    if (gate != null) await gate!.future;
    permission = requestedPermission;
    return current;
  }

  @override
  Future<ReminderState> configure({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    configurations++;
    if (failConfigure) throw StateError('configuration failed');
    this.enabled = enabled;
    this.hour = hour;
    this.minute = minute;
    if (failAfterCommit) throw StateError('scheduling failed');
    return current;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Future<void> sendTest() async {
    testsSent++;
  }
}

Future<ReminderController> quietReminders() async {
  final controller = ReminderController(FakeReminderService());
  await controller.refresh();
  return controller;
}
