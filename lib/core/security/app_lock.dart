import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Verrouillage de l'app : code PIN (haché) + biométrie optionnelle.
class AppLock {
  AppLock._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _auth = LocalAuthentication();

  static const _pinKey = 'app_lock_pin_hash';
  static const _bioKey = 'app_lock_biometric';

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('mylife:$pin')).toString();

  static Future<bool> isEnabled() async {
    final h = await _storage.read(key: _pinKey);
    return h != null && h.isNotEmpty;
  }

  static Future<void> setPin(String pin) =>
      _storage.write(key: _pinKey, value: _hash(pin));

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    return stored != null && stored == _hash(pin);
  }

  static Future<void> disable() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _bioKey);
  }

  static Future<bool> biometricEnabled() async =>
      (await _storage.read(key: _bioKey)) == '1';

  static Future<void> setBiometricEnabled(bool on) =>
      _storage.write(key: _bioKey, value: on ? '1' : '0');

  /// Vrai si l'appareil dispose d'une biométrie utilisable.
  static Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Lance l'authentification biométrique. Renvoie vrai si réussie.
  static Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Déverrouiller MyLife',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
