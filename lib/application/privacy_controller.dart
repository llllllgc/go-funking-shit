import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/privacy_services.dart';

class PrivacyController extends ChangeNotifier {
  PrivacyController({
    required this.store,
    required this.auth,
    required this.screen,
  });
  final AppLockStore store;
  final DeviceAuthenticator auth;
  final PrivacyScreenBridge screen;

  bool _ready = false;
  bool _enabled = false;
  bool _locked = true;
  bool _busy = false;
  bool _disposed = false;
  bool _fault = false;
  int _epoch = 0;
  int? _authenticatedEpoch;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  String? _message;
  final Map<Completer<bool>, int> _interactionWaiters = {};

  int get accessEpoch => _epoch;
  bool allowsInteraction(int epoch) =>
      !_disposed && epoch == _epoch && !concealed;
  bool get enabled => _enabled;
  bool get busy => _busy;
  bool get ready => _ready;
  bool get fault => _fault;
  String? get message => _message;
  bool get concealed =>
      !_ready || _fault || _locked || _lifecycle != AppLifecycleState.resumed;

  /// A permission callback can arrive just before its matching resume event.
  /// Only an unlocked, unchanged session may wait through that brief inactive
  /// state. A real background transition, lock, reload or disposal cancels it.
  Future<bool> waitForInteraction(int epoch) {
    final decision = _interactionDecision(epoch);
    if (decision != null) return Future.value(decision);
    final waiter = Completer<bool>();
    _interactionWaiters[waiter] = epoch;
    return waiter.future;
  }

  bool? _interactionDecision(int epoch) {
    if (_disposed || epoch != _epoch || !_ready || _fault || _locked) {
      return false;
    }
    if (_lifecycle == AppLifecycleState.resumed) return true;
    return _lifecycle == AppLifecycleState.inactive ? null : false;
  }

  void _settleInteractionWaiters() {
    for (final entry in _interactionWaiters.entries.toList()) {
      final decision = _interactionDecision(entry.value);
      if (decision != null) {
        _interactionWaiters.remove(entry.key);
        entry.key.complete(decision);
      }
    }
  }

  Future<void> initialize() async {
    // Failure propagates to bootstrap: a failed read is never treated as off.
    _ready = false;
    _locked = true;
    _authenticatedEpoch = null;
    _epoch++;
    notifyListeners();
    final enabled = await store.readLockEnabled();
    await screen.setProtected(enabled);
    if (_disposed) return;
    _enabled = enabled;
    _locked = enabled;
    _ready = true;
    _fault = false;
    _message = null;
    notifyListeners();
  }

  void lifecycleChanged(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.inactive && _enabled && !_busy) {
      _epoch++;
      _authenticatedEpoch = null;
      _locked = true;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _epoch++;
      _authenticatedEpoch = null;
      _locked = _enabled;
      if (_busy) unawaited(auth.cancel().catchError((Object _) {}));
    } else if (state == AppLifecycleState.resumed &&
        _authenticatedEpoch == _epoch) {
      _locked = false;
      _authenticatedEpoch = null;
    }
    notifyListeners();
  }

  void lock() {
    if (!_enabled) return;
    _epoch++;
    _authenticatedEpoch = null;
    _locked = true;
    _message = null;
    notifyListeners();
  }

  Future<bool> unlock() async {
    if (!_ready || _fault || _busy || !_enabled || _disposed) return false;
    final epoch = _epoch;
    _begin();
    try {
      final passed = await auth.authenticate('解锁保存在这台设备上的记录');
      if (_disposed) return false;
      if (epoch != _epoch) {
        _message = '验证期间离开了应用，请重新尝试。';
        return false;
      }
      if (!passed) {
        _message = '未完成验证，记录仍已锁定。';
        return false;
      }
      _grantAfterResume(epoch);
      return true;
    } on AuthFailure catch (error) {
      _message = error.message;
      return false;
    } catch (_) {
      _message = '验证失败，请重试。记录仍已锁定。';
      return false;
    } finally {
      _end();
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (!_ready || _fault || _busy || _disposed) return false;
    if (value == _enabled) return true;
    final epoch = _epoch;
    _begin();
    try {
      final passed = await auth.authenticate(
        value ? '验证设备身份以开启应用锁' : '验证设备身份以关闭应用锁',
      );
      if (_disposed) return false;
      if (epoch != _epoch) {
        _message = '验证期间离开了应用，请重新尝试。';
        return false;
      }
      if (!passed) {
        _message = '验证未完成，设置未更改。';
        return false;
      }
      try {
        await screen.setProtected(value);
        await store.writeLockEnabled(value);
      } catch (_) {
        // An uncertain preference or native result must never expose records.
        _fault = true;
        _locked = true;
        _message = '无法确认隐私设置，请重试。记录内容暂时隐藏。';
        return false;
      }
      if (_disposed) return false;
      _enabled = value;
      _locked = value;
      if (value && epoch == _epoch) _grantAfterResume(epoch);
      if (!value) _locked = false;
      _message = value ? '应用锁已开启。切到后台后会重新锁定。' : '应用锁已关闭。';
      return true;
    } on AuthFailure catch (error) {
      _message = error.message;
      return false;
    } catch (_) {
      _message = '暂时无法验证身份，设置未更改。';
      return false;
    } finally {
      _end();
    }
  }

  Future<void> retrySettings() async {
    if (_busy || _disposed) return;
    _begin();
    try {
      await initialize();
    } catch (_) {
      _fault = true;
      _message = '仍无法读取隐私设置，请稍后重试。';
    } finally {
      _end();
    }
  }

  void _grantAfterResume(int epoch) {
    if (_lifecycle == AppLifecycleState.resumed) {
      _locked = false;
    } else if (_lifecycle == AppLifecycleState.inactive) {
      // Native auth can return just before the matching resumed event.
      _authenticatedEpoch = epoch;
    }
  }

  void _begin() {
    _busy = true;
    _message = null;
    notifyListeners();
  }

  void _end() {
    _busy = false;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _settleInteractionWaiters();
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _settleInteractionWaiters();
    if (_busy) unawaited(auth.cancel().catchError((Object _) {}));
    super.dispose();
  }
}
