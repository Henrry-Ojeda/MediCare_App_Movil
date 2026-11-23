import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecureSession {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _localAuth = LocalAuthentication();

  static const _kTokenKey = 'medicare_jwt_token';
  static const _kUserIdKey = 'medicare_user_id';
  static const _kRoleCodeKey = 'medicare_role_code';
  static const _kDictationEnabledKey = 'medicare_dictation_enabled';
  static const _kDoctorNameKey = 'medicare_doctor_name';
  static const _kDoctorEmailKey = 'medicare_doctor_email';
  static const _kBiometricEnabledKey = 'medicare_biometric_enabled';

  static Future<void> saveSession({
    required String token,
    required String doctorName,
    required String email,
    String? userId,
    String? roleCode,
    bool dictationEnabled = false,
  }) async {
    await _storage.write(key: _kTokenKey, value: token);
    await _storage.write(key: _kDoctorNameKey, value: doctorName);
    await _storage.write(key: _kDoctorEmailKey, value: email);
    if (userId != null) {
      await _storage.write(key: _kUserIdKey, value: userId);
    }
    if (roleCode != null) {
      await _storage.write(key: _kRoleCodeKey, value: roleCode);
    }
    await _storage.write(
      key: _kDictationEnabledKey,
      value: dictationEnabled ? '1' : '0',
    );
  }

  static Future<String?> getToken() => _storage.read(key: _kTokenKey);
  static Future<String?> getUserId() => _storage.read(key: _kUserIdKey);
  static Future<String?> getRoleCode() => _storage.read(key: _kRoleCodeKey);
  static Future<bool> isDictationEnabled() async =>
      (await _storage.read(key: _kDictationEnabledKey)) == '1';
  static Future<String?> getDoctorName() => _storage.read(key: _kDoctorNameKey);
  static Future<String?> getDoctorEmail() => _storage.read(key: _kDoctorEmailKey);

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _kBiometricEnabledKey, value: enabled ? '1' : '0');
  }

  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _kBiometricEnabledKey);
    return val == '1';
  }

  static Future<bool> authenticateWithBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canCheck) return false;
    return _localAuth.authenticate(
      localizedReason: 'Confirma tu identidad para acceder a historias clínicas',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
  }

  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}

