import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Libellés récurrents exclus manuellement par l'utilisateur
/// (« ce n'est pas une charge/un revenu fixe »).
class RecurringPrefs {
  RecurringPrefs._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'recurring_excluded';

  static Future<Set<String>> excludedLabels() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    return raw.split('\n').where((s) => s.trim().isNotEmpty).toSet();
  }

  static Future<void> exclude(String label) async {
    final set = await excludedLabels()..add(label);
    await _storage.write(key: _key, value: set.join('\n'));
  }

  static Future<void> include(String label) async {
    final set = await excludedLabels()..remove(label);
    await _storage.write(key: _key, value: set.join('\n'));
  }
}
