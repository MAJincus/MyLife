import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service de notifications locales (rappels agenda + prises de médicaments).
class Notifications {
  Notifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    final android$ = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android$?.requestNotificationsPermission();
    await android$?.requestExactAlarmsPermission();
    _ready = true;
  }

  static const _channel = AndroidNotificationDetails(
    'mylife_reminders',
    'Rappels',
    channelDescription: 'Rappels agenda et prises de médicaments',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Planifie une notification unique à [when].
  static Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await init();
    if (when.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Notification quotidienne à [hour]:[minute] (pour les médicaments).
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Planifie un rappel selon une règle de répétition.
  /// [repeatRule] : 'none' | 'daily' | 'weekly' | 'monthly'.
  /// ('monthly' est planifié en one-shot à la prochaine occurrence.)
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String repeatRule,
  }) async {
    await init();

    DateTimeComponents? match;
    switch (repeatRule) {
      case 'daily':
        match = DateTimeComponents.time;
      case 'weekly':
        match = DateTimeComponents.dayOfWeekAndTime;
      default:
        match = null; // 'none' et 'monthly' → occurrence unique
    }

    // Pour une occurrence unique déjà passée, on n'a rien à planifier.
    var target = tz.TZDateTime.from(when, tz.local);
    if (match == null && target.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      target,
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: match,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
}
