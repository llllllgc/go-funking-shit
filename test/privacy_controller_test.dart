import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/privacy_controller.dart';
import 'package:lalema/data/privacy_services.dart';

import 'support/privacy_fakes.dart';

void main() {
  late MemoryLockStore store;
  late FakeAuthenticator auth;
  late FakePrivacyScreen screen;
  late PrivacyController privacy;
  setUp(() {
    store = MemoryLockStore();
    auth = FakeAuthenticator();
    screen = FakePrivacyScreen();
    privacy = PrivacyController(store: store, auth: auth, screen: screen);
  });
  tearDown(() => privacy.dispose());

  test(
    'an old interaction lease stays invalid even after a later unlock',
    () async {
      store.enabled = true;
      await privacy.initialize();
      await privacy.unlock();
      final before = privacy.accessEpoch;
      expect(privacy.allowsInteraction(before), isTrue);
      privacy.lifecycleChanged(AppLifecycleState.paused);
      privacy.lifecycleChanged(AppLifecycleState.resumed);
      await privacy.unlock();
      expect(privacy.allowsInteraction(before), isFalse);
      expect(privacy.allowsInteraction(privacy.accessEpoch), isTrue);
    },
  );

  test('ordinary inactive interruptions relock an unlocked session', () async {
    store.enabled = true;
    await privacy.initialize();
    await privacy.unlock();
    privacy.lifecycleChanged(AppLifecycleState.inactive);
    privacy.lifecycleChanged(AppLifecycleState.resumed);
    expect(privacy.concealed, isTrue);
    expect(await privacy.unlock(), isTrue);
  });

  test(
    'configuration reload failure also conceals an already open session',
    () async {
      await privacy.initialize();
      store.failRead = true;
      await expectLater(privacy.initialize(), throwsStateError);
      expect(privacy.ready, isFalse);
      expect(privacy.concealed, isTrue);
    },
  );

  test(
    'disabled by default; enabled setting starts locked and protected',
    () async {
      expect(privacy.concealed, isTrue);
      await privacy.initialize();
      expect(privacy.concealed, isFalse);
      expect(auth.attempts, 0);
      store.enabled = true;
      await privacy.initialize();
      expect(privacy.enabled, isTrue);
      expect(privacy.concealed, isTrue);
      expect(screen.protected, isTrue);
    },
  );

  test(
    'failed settings read never defaults to an unlocked application',
    () async {
      store.failRead = true;
      await expectLater(privacy.initialize(), throwsStateError);
      expect(privacy.ready, isFalse);
      expect(privacy.concealed, isTrue);
      expect(await privacy.unlock(), isFalse);
    },
  );

  test(
    'enable and disable both require successful device verification',
    () async {
      await privacy.initialize();
      auth.success = false;
      expect(await privacy.setEnabled(true), isFalse);
      expect(store.writes, 0);
      auth.success = true;
      expect(await privacy.setEnabled(true), isTrue);
      expect(store.enabled, isTrue);
      expect(privacy.concealed, isFalse);
      auth.success = false;
      expect(await privacy.setEnabled(false), isFalse);
      expect(store.enabled, isTrue);
      auth.success = true;
      expect(await privacy.setEnabled(false), isTrue);
      expect(store.enabled, isFalse);
      expect(screen.protected, isFalse);
      expect(auth.attempts, 4);
    },
  );

  test(
    'cancelled or unavailable authentication retains the locked state',
    () async {
      store.enabled = true;
      await privacy.initialize();
      auth.success = false;
      expect(await privacy.unlock(), isFalse);
      expect(privacy.concealed, isTrue);
      auth.failure = const AuthFailure('请设置设备密码');
      expect(await privacy.unlock(), isFalse);
      expect(privacy.message, '请设置设备密码');
      expect(privacy.concealed, isTrue);
    },
  );

  test('background invalidates a delayed successful verification', () async {
    store.enabled = true;
    await privacy.initialize();
    auth.gate = Completer<bool>();
    final unlocking = privacy.unlock();
    privacy.lifecycleChanged(AppLifecycleState.paused);
    privacy.lifecycleChanged(AppLifecycleState.resumed);
    auth.gate!.complete(true);
    expect(await unlocking, isFalse);
    expect(privacy.concealed, isTrue);
    expect(auth.cancels, 1);
    auth.gate = null;
    expect(await privacy.unlock(), isTrue);
    expect(privacy.concealed, isFalse);
  });

  test('native auth completing during inactive waits for resume', () async {
    store.enabled = true;
    await privacy.initialize();
    auth.gate = Completer<bool>();
    final unlocking = privacy.unlock();
    privacy.lifecycleChanged(AppLifecycleState.inactive);
    auth.gate!.complete(true);
    expect(await unlocking, isTrue);
    expect(privacy.concealed, isTrue);
    privacy.lifecycleChanged(AppLifecycleState.resumed);
    expect(privacy.concealed, isFalse);
    privacy.lifecycleChanged(AppLifecycleState.hidden);
    privacy.lifecycleChanged(AppLifecycleState.resumed);
    expect(privacy.concealed, isTrue);
  });

  test(
    'pending enable cannot persist after a real background transition',
    () async {
      await privacy.initialize();
      auth.gate = Completer<bool>();
      final enabling = privacy.setEnabled(true);
      expect(await privacy.setEnabled(true), isFalse);
      privacy.lifecycleChanged(AppLifecycleState.paused);
      auth.gate!.complete(true);
      expect(await enabling, isFalse);
      expect(store.writes, 0);
      expect(privacy.enabled, isFalse);
    },
  );

  test(
    'uncertain setting writes hide everything until configuration reload succeeds',
    () async {
      store.enabled = true;
      await privacy.initialize();
      await privacy.unlock();
      store.failWrite = true;
      expect(await privacy.setEnabled(false), isFalse);
      expect(privacy.fault, isTrue);
      expect(privacy.concealed, isTrue);
      expect(store.enabled, isTrue);
      store.failWrite = false;
      await privacy.retrySettings();
      expect(privacy.fault, isFalse);
      expect(screen.protected, isTrue);
      expect(privacy.concealed, isTrue);
      await privacy.unlock();
      expect(privacy.concealed, isFalse);
    },
  );

  test('native protection failure also fails closed', () async {
    await privacy.initialize();
    screen.fail = true;
    expect(await privacy.setEnabled(true), isFalse);
    expect(store.writes, 0);
    expect(privacy.fault, isTrue);
    expect(privacy.concealed, isTrue);
  });
}
