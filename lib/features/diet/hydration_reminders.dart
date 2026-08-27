import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/notifications.dart';

/// Rappels de boire, à intervalle régulier dans une fenêtre horaire.
class HydrationReminders {
  HydrationReminders._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _enabledKey = 'hydration_reminders_on';
  static const _intervalKey = 'hydration_interval';
  static const _base = 800000; // espace d'ID de notifications dédié
  static const _startHour = 8;
  static const _endHour = 21;

  static Future<bool> isEnabled() async =>
      (await _storage.read(key: _enabledKey)) == '1';

  static Future<int> intervalHours() async =>
      int.tryParse(await _storage.read(key: _intervalKey) ?? '') ?? 2;

  static Future<void> configure({required bool enabled, int? interval}) async {
    await _storage.write(key: _enabledKey, value: enabled ? '1' : '0');
    if (interval != null) {
      await _storage.write(key: _intervalKey, value: '$interval');
    }
    await _reschedule();
  }

  static Future<void> _reschedule() async {
    // Annule tous les créneaux possibles.
    for (var h = _startHour; h <= _endHour; h++) {
      await Notifications.cancel(_base + h);
    }
    if (!await isEnabled()) return;

    final step = (await intervalHours()).clamp(1, 6);
    for (var h = _startHour; h <= _endHour; h += step) {
      await Notifications.scheduleDaily(
        id: _base + h,
        title: '💧 Hydratation',
        body: 'Pense à boire un verre d\'eau.',
        hour: h,
        minute: 0,
      );
    }
  }
}
