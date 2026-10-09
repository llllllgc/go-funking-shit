import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

abstract interface class AppLockStore {
  Future<bool> readLockEnabled();
  Future<void> writeLockEnabled(bool enabled);
}

abstract interface class DeviceAuthenticator {
  Future<bool> authenticate(String reason);
  Future<void> cancel();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

class SystemDeviceAuthenticator implements DeviceAuthenticator {
  final _auth = LocalAuthentication();
  @override
  Future<bool> authenticate(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) {
        throw const AuthFailure('此设备暂不能验证身份，请先设置设备锁屏密码。');
      }
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: false,
        authMessages: const [
          AndroidAuthMessages(signInTitle: '验证设备身份', cancelButton: '取消'),
          IOSAuthMessages(cancelButton: '取消'),
        ],
      );
    } on LocalAuthException catch (error) {
      throw AuthFailure(switch (error.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled => '请先在设备设置中配置锁屏密码、面容或指纹。',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => '系统验证暂时锁定，请稍后重试或使用设备密码。',
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled => '验证已取消。',
        _ => '暂时无法完成系统验证，请重试。',
      });
    }
  }

  @override
  Future<void> cancel() async {
    await _auth.stopAuthentication();
  }
}

abstract interface class PrivacyScreenBridge {
  Future<void> setProtected(bool enabled);
  Future<int?> foregroundEpoch();
  Future<void> frameReady(int epoch);
}

class NativePrivacyScreen implements PrivacyScreenBridge {
  const NativePrivacyScreen();
  static const _channel = MethodChannel('lalema/privacy_screen');
  @override
  Future<void> setProtected(bool enabled) =>
      _channel.invokeMethod<void>('protect', enabled);
  @override
  Future<int?> foregroundEpoch() =>
      _channel.invokeMethod<int>('foregroundEpoch');
  @override
  Future<void> frameReady(int epoch) =>
      _channel.invokeMethod<void>('frameReady', epoch);
}
