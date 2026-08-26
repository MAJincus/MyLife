import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/notifications.dart';

/// Notification hebdomadaire invitant à faire le bilan de la semaine
/// avec l'assistant (dimanche 19 h).
class WeeklyReport {
  WeeklyReport._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _flag = 'weekly_report_on';
  static const _notifId = 900000;

  static Future<bool> isEnabled() async =>
      (await _storage.read(key: _flag)) == '1';

  static Future<void> setEnabled(bool on) async {
    await _storage.write(key: _flag, value: on ? '1' : '0');
    if (on) {
      await _schedule();
    } else {
      await Notifications.cancel(_notifId);
    }
  }

  static Future<void> _schedule() async {
    // Prochain dimanche à 19 h (weekday: 7 = dimanche).
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 19);
    while (next.weekday != DateTime.sunday || next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    await Notifications.scheduleReminder(
      id: _notifId,
      title: '📊 Bilan de la semaine',
      body: 'Ouvre MyLife et demande à ton coach « Fais le point sur ma '
          'semaine ».',
      when: next,
      repeatRule: 'weekly',
    );
  }
}
