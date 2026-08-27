import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

/// Un agenda du téléphone (compte Google, Outlook…).
class DeviceCal {
  DeviceCal({
    required this.id,
    required this.name,
    required this.account,
    required this.accountType,
    required this.isReadOnly,
    this.color,
  });
  final String id;
  final String name;
  final String account;
  final String accountType;
  final bool isReadOnly;
  final int? color;

  /// Fournisseur déduit du type de compte.
  String get provider {
    final t = accountType.toLowerCase();
    if (t.contains('google')) return 'Google';
    if (t.contains('outlook') ||
        t.contains('microsoft') ||
        t.contains('exchange') ||
        t.contains('office')) {
      return 'Outlook';
    }
    if (t.contains('local')) return 'Local';
    return account.isEmpty ? 'Autre' : account;
  }
}

/// Un événement externe lu depuis un agenda du téléphone.
class CalEvent {
  CalEvent({
    required this.id,
    required this.calendarId,
    required this.calendarName,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    this.color,
  });
  final String id;
  final String calendarId;
  final String calendarName;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final int? color;
}

/// Accès aux agendas du téléphone (Google/Outlook synchronisés) via
/// le fournisseur de calendrier système. Lecture + écriture.
class CalendarService {
  final _plugin = DeviceCalendarPlugin();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _selectedKey = 'cal_selected_ids';
  static const _writeKey = 'cal_write_id';

  // ---------- Permissions ----------

  Future<bool> hasPermission() async {
    final r = await _plugin.hasPermissions();
    return r.data ?? false;
  }

  Future<bool> requestPermission() async {
    var r = await _plugin.hasPermissions();
    if (r.data != true) r = await _plugin.requestPermissions();
    return r.data ?? false;
  }

  // ---------- Agendas ----------

  Future<List<DeviceCal>> listCalendars() async {
    final r = await _plugin.retrieveCalendars();
    final cals = r.data ?? [];
    return [
      for (final c in cals)
        if (c.id != null)
          DeviceCal(
            id: c.id!,
            name: c.name ?? 'Agenda',
            account: c.accountName ?? '',
            accountType: c.accountType ?? '',
            isReadOnly: c.isReadOnly ?? false,
            color: c.color,
          ),
    ];
  }

  // ---------- Lecture d'événements ----------

  Future<List<CalEvent>> eventsBetween(
      List<String> calendarIds, DateTime start, DateTime end) async {
    if (calendarIds.isEmpty) return [];
    final cals = await listCalendars();
    final byId = {for (final c in cals) c.id: c};

    final result = <CalEvent>[];
    for (final id in calendarIds) {
      final r = await _plugin.retrieveEvents(
        id,
        RetrieveEventsParams(startDate: start, endDate: end),
      );
      for (final e in r.data ?? const <Event>[]) {
        if (e.start == null || e.eventId == null) continue;
        result.add(CalEvent(
          id: e.eventId!,
          calendarId: id,
          calendarName: byId[id]?.name ?? 'Agenda',
          title: e.title ?? '(Sans titre)',
          start: e.start!,
          end: e.end ?? e.start!,
          allDay: e.allDay ?? false,
          color: byId[id]?.color,
        ));
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  // ---------- Écriture ----------

  /// Crée un événement dans [calendarId]. Renvoie l'id créé ou null.
  Future<String?> createEvent({
    required String calendarId,
    required String title,
    String? description,
    required DateTime start,
    required DateTime end,
  }) async {
    final event = Event(
      calendarId,
      title: title,
      description: description,
      start: TZDateTime.from(start, local),
      end: TZDateTime.from(end, local),
    );
    final res = await _plugin.createOrUpdateEvent(event);
    return res?.data;
  }

  // ---------- Préférences (agendas affichés / cible d'écriture) ----------

  Future<List<String>> selectedCalendarIds() async {
    final raw = await _storage.read(key: _selectedKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  Future<void> setSelectedCalendarIds(List<String> ids) =>
      _storage.write(key: _selectedKey, value: ids.join(','));

  Future<String?> writeCalendarId() => _storage.read(key: _writeKey);

  Future<void> setWriteCalendarId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _writeKey);
    } else {
      await _storage.write(key: _writeKey, value: id);
    }
  }
}

/// Événements externes des agendas sélectionnés, sur ~30 jours.
/// Invalidé après changement de sélection ou rafraîchissement manuel.
final externalEventsProvider = FutureProvider<List<CalEvent>>((ref) async {
  final svc = ref.watch(calendarServiceProvider);
  if (!await svc.hasPermission()) return [];
  final ids = await svc.selectedCalendarIds();
  if (ids.isEmpty) return [];
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 1));
  final end = start.add(const Duration(days: 61));
  return svc.eventsBetween(ids, start, end);
});
