import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/reminder_service.dart';

class ReminderController extends ChangeNotifier {
  ReminderController(
    this._service, {
    bool Function()? canInteract,
    int Function()? interactionEpoch,
    this.waitForInteraction,
  }) : _canInteract = canInteract ?? _alwaysAllow,
       _interactionEpoch = interactionEpoch ?? _defaultEpoch;
  static bool _alwaysAllow() => true;
  static int _defaultEpoch() => 0;
  final ReminderService _service;
  final bool Function() _canInteract;
  final int Function() _interactionEpoch;
  final Future<bool> Function(int)? waitForInteraction;
  ReminderState? _state;
  ReminderState? get state => _state;
  bool _busy = false;
  bool get busy => _busy;
  bool _disposed = false;
  bool _refreshPending = false;
  String? _message;
  String? get message => _message;
  bool _uncertain = false;
  bool get uncertain => _uncertain;

  Future<void> refresh() async {
    if (_disposed) return;
    if (_busy) {
      _refreshPending = true;
      return;
    }
    await _run(() async {
      _state = await _service.read();
      _uncertain = false;
    });
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_allow() || _state == null || _uncertain) return;
    await _run(() async {
      if (enabled && _state!.permission != ReminderPermission.allowed) {
        final epoch = _interactionEpoch();
        _state = await _service.requestPermission();
        if (_state!.permission != ReminderPermission.allowed) {
          _message = '通知尚未允许，你仍可正常记录。可到系统设置中开启通知。';
          return;
        }
        if (_disposed) return;
        final resumed = waitForInteraction == null
            ? _canInteract()
            : await waitForInteraction!(epoch);
        if (_disposed ||
            !resumed ||
            epoch != _interactionEpoch() ||
            !_canInteract()) {
          _message = '通知权限已更新，返回并解锁后可继续开启提醒。';
          return;
        }
      }
      final old = _state!;
      _uncertain = true;
      _state = await _service.configure(
        enabled: enabled,
        hour: old.hour,
        minute: old.minute,
      );
      _uncertain = false;
      _message = !enabled
          ? '每日提醒已关闭。'
          : _state!.scheduled
          ? '每日提醒已安排。'
          : '设置已保存，提醒尚未安排，请重新检查。';
    });
  }

  Future<void> setTime(int hour, int minute) async {
    if (!_allow() || _state == null || _uncertain) return;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;
    await _run(() async {
      _uncertain = true;
      _state = await _service.configure(
        enabled: _state!.enabled,
        hour: hour,
        minute: minute,
      );
      _uncertain = false;
      _message = !_state!.enabled
          ? '时间已保存，开启后生效。'
          : _state!.scheduled
          ? '提醒时间已更新。'
          : '时间已保存，提醒尚未安排，请重新检查。';
    });
  }

  Future<void> openSettings() async {
    if (!_allow()) return;
    await _run(_service.openSettings);
  }

  Future<void> sendTest() async {
    if (!_allow() || _state?.permission != ReminderPermission.allowed) return;
    await _run(() async {
      await _service.sendTest();
      _message = '测试提醒已交给系统。若未看到，请检查系统通知和专注模式设置。';
    });
  }

  bool _allow() => !_disposed && !_busy && _canInteract();

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      _uncertain = true;
      _message = '未能确认提醒状态，请重试。记录功能不受影响。';
    } finally {
      _busy = false;
      notifyListeners();
      if (_refreshPending && !_disposed) {
        _refreshPending = false;
        unawaited(refresh());
      }
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
