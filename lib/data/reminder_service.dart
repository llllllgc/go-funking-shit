import 'package:flutter/services.dart';

enum ReminderPermission { allowed, denied, notDetermined }

class ReminderState {
  const ReminderState({
    this.enabled = false,
    this.hour = 20,
    this.minute = 0,
    this.permission = ReminderPermission.notDetermined,
    this.scheduled = false,
    this.nextAt,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final ReminderPermission permission;
  final bool scheduled;
  final DateTime? nextAt;

  factory ReminderState.fromMap(Map<Object?, Object?> value) {
    final hour = value['hour'];
    final minute = value['minute'];
    final permission = value['permission'];
    final next = value['nextAt'];
    if (value['enabled'] is! bool ||
        value['scheduled'] is! bool ||
        hour is! int ||
        hour < 0 ||
        hour > 23 ||
        minute is! int ||
        minute < 0 ||
        minute > 59 ||
        !ReminderPermission.values.any((item) => item.name == permission) ||
        (next != null && next is! int) ||
        (value['scheduled'] == true &&
            (value['enabled'] != true ||
                permission != 'allowed' ||
                next == null))) {
      throw const FormatException('Invalid reminder state');
    }
    return ReminderState(
      enabled: value['enabled'] as bool,
      hour: hour,
      minute: minute,
      permission: ReminderPermission.values.byName(permission as String),
      scheduled: value['scheduled'] as bool,
      nextAt: next == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(next as int),
    );
  }
}

abstract interface class ReminderService {
  Future<ReminderState> read();
  Future<ReminderState> requestPermission();
  Future<ReminderState> configure({
    required bool enabled,
    required int hour,
    required int minute,
  });
  Future<void> openSettings();
  Future<void> sendTest();
}

class NativeReminderService implements ReminderService {
  const NativeReminderService();
  static const _channel = MethodChannel('lalema/reminders');

  Future<ReminderState> _state(
    String method, [
    Map<String, Object>? args,
  ]) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      method,
      args,
    );
    if (value == null) throw const FormatException('Missing reminder state');
    return ReminderState.fromMap(value);
  }

  @override
  Future<ReminderState> read() => _state('getState');
  @override
  Future<ReminderState> requestPermission() => _state('requestPermission');
  @override
  Future<ReminderState> configure({
    required bool enabled,
    required int hour,
    required int minute,
  }) =>
      _state('configure', {'enabled': enabled, 'hour': hour, 'minute': minute});
  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');
  @override
  Future<void> sendTest() => _channel.invokeMethod<void>('test');
}
