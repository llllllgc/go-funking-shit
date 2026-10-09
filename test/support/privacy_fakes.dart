import 'dart:async';

import 'package:lalema/application/privacy_controller.dart';
import 'package:lalema/data/privacy_services.dart';

class MemoryLockStore implements AppLockStore {
  MemoryLockStore({this.enabled = false});
  bool enabled;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<bool> readLockEnabled() async {
    if (failRead) throw StateError('read failed');
    return enabled;
  }

  @override
  Future<void> writeLockEnabled(bool value) async {
    writes++;
    if (failWrite) throw StateError('write failed');
    enabled = value;
  }
}

class FakeAuthenticator implements DeviceAuthenticator {
  bool success = true;
  int attempts = 0;
  int cancels = 0;
  Completer<bool>? gate;
  Object? failure;
  @override
  Future<bool> authenticate(String reason) async {
    attempts++;
    if (failure != null) throw failure!;
    return gate?.future ?? success;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class FakePrivacyScreen implements PrivacyScreenBridge {
  bool fail = false;
  bool protected = false;
  int frames = 0;
  @override
  Future<void> setProtected(bool value) async {
    if (fail) throw StateError('native protection unavailable');
    protected = value;
  }

  @override
  Future<int?> foregroundEpoch() async => 0;
  @override
  Future<void> frameReady(int epoch) async {
    frames++;
  }
}

Future<PrivacyController> unlockedPrivacy() async {
  final controller = PrivacyController(
    store: MemoryLockStore(),
    auth: FakeAuthenticator(),
    screen: FakePrivacyScreen(),
  );
  await controller.initialize();
  return controller;
}
