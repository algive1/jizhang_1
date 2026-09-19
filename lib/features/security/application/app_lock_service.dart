import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(),
);

class AppLockService {
  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? authentication,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _authentication = authentication ?? LocalAuthentication();

  static const _enabledKey = 'app.lock.enabled.v1';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _authentication;

  Future<bool> isEnabled() async =>
      await _storage.read(key: _enabledKey) == '1';

  Future<bool> isSupported() async {
    try {
      return await _authentication.isDeviceSupported();
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = '验证身份后进入好好记账',
  }) async {
    try {
      if (!await _authentication.isDeviceSupported()) return false;
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!enabled) {
      await _storage.delete(key: _enabledKey);
      return true;
    }
    if (!await isSupported()) return false;
    final verified = await authenticate(reason: '验证身份以开启应用锁');
    if (!verified) return false;
    await _storage.write(key: _enabledKey, value: '1');
    return true;
  }
}
