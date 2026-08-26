import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé (Keystore Android) pour :
///  - la clé de chiffrement de la base SQLCipher (générée une fois)
///  - la clé API Claude saisie par l'utilisateur
class SecureStore {
  SecureStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _dbKeyName = 'mylife_db_key';
  static const _claudeKeyName = 'claude_api_key';

  /// Renvoie la clé de chiffrement de la base, en la générant au 1er lancement.
  static Future<String> databaseKey() async {
    final existing = await _storage.read(key: _dbKeyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _dbKeyName, value: key);
    return key;
  }

  static Future<String?> claudeApiKey() =>
      _storage.read(key: _claudeKeyName);

  static Future<void> setClaudeApiKey(String key) =>
      _storage.write(key: _claudeKeyName, value: key.trim());

  static Future<void> clearClaudeApiKey() =>
      _storage.delete(key: _claudeKeyName);
}
