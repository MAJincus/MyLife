import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/providers.dart';
import '../../data/database.dart';

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(databaseProvider));
});

class HealthRepository {
  HealthRepository(this.db);
  final AppDatabase db;

  // ---------- Sommeil ----------

  Stream<List<SleepEntry>> watchSleep({int limit = 60}) {
    return (db.select(db.sleepEntries)
          ..orderBy([
            (s) => OrderingTerm(expression: s.date, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> addSleep({
    required DateTime bedTime,
    required DateTime wakeTime,
    required int quality,
    String note = '',
  }) {
    var wake = wakeTime;
    if (!wake.isAfter(bedTime)) wake = wake.add(const Duration(days: 1));
    final minutes = wake.difference(bedTime).inMinutes;
    return db.into(db.sleepEntries).insert(SleepEntriesCompanion.insert(
          date: DateTime(wake.year, wake.month, wake.day),
          bedTime: bedTime,
          wakeTime: wake,
          durationMinutes: minutes,
          quality: Value(quality),
          note: Value(note),
        ));
  }

  Future<void> updateSleep(
    int id, {
    required DateTime bedTime,
    required DateTime wakeTime,
    required int quality,
    String note = '',
  }) {
    var wake = wakeTime;
    if (!wake.isAfter(bedTime)) wake = wake.add(const Duration(days: 1));
    final minutes = wake.difference(bedTime).inMinutes;
    return (db.update(db.sleepEntries)..where((s) => s.id.equals(id))).write(
      SleepEntriesCompanion(
        date: Value(DateTime(wake.year, wake.month, wake.day)),
        bedTime: Value(bedTime),
        wakeTime: Value(wake),
        durationMinutes: Value(minutes),
        quality: Value(quality),
        note: Value(note),
      ),
    );
  }

  Future<void> deleteSleep(int id) =>
      (db.delete(db.sleepEntries)..where((s) => s.id.equals(id))).go();

  // ---------- Douleurs ----------

  Stream<List<PainEntry>> watchPain({int limit = 100}) {
    return (db.select(db.painEntries)
          ..orderBy([
            (p) => OrderingTerm(expression: p.at, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> addPain({
    required DateTime at,
    required String location,
    required int intensity,
    String note = '',
  }) {
    return db.into(db.painEntries).insert(PainEntriesCompanion.insert(
          at: at,
          location: Value(location),
          intensity: Value(intensity),
          note: Value(note),
        ));
  }

  Future<void> updatePain(
    int id, {
    required String location,
    required int intensity,
    String note = '',
  }) {
    return (db.update(db.painEntries)..where((p) => p.id.equals(id))).write(
      PainEntriesCompanion(
        location: Value(location),
        intensity: Value(intensity),
        note: Value(note),
      ),
    );
  }

  Future<void> deletePain(int id) =>
      (db.delete(db.painEntries)..where((p) => p.id.equals(id))).go();

  // ---------- Médicaments ----------

  Stream<List<Medication>> watchMedications() {
    return (db.select(db.medications)
          ..where((m) => m.active.equals(true))
          ..orderBy([(m) => OrderingTerm(expression: m.name)]))
        .watch();
  }

  Future<void> addMedication({
    required String name,
    required String dosage,
    required List<String> times, // "08:00"
    required bool remindersOn,
    String note = '',
  }) async {
    final id = await db.into(db.medications).insert(MedicationsCompanion.insert(
          name: name,
          dosage: Value(dosage),
          scheduleTimes: Value(times.join(',')),
          remindersOn: Value(remindersOn),
          note: Value(note),
        ));
    if (remindersOn) await _scheduleReminders(id, name, dosage, times);
  }

  Future<void> deactivateMedication(Medication med) async {
    await (db.update(db.medications)..where((m) => m.id.equals(med.id)))
        .write(const MedicationsCompanion(active: Value(false)));
    await _cancelReminders(med.id, _parseTimes(med.scheduleTimes).length);
  }

  Future<void> toggleReminders(Medication med, bool on) async {
    await (db.update(db.medications)..where((m) => m.id.equals(med.id)))
        .write(MedicationsCompanion(remindersOn: Value(on)));
    final times = _parseTimes(med.scheduleTimes);
    if (on) {
      await _scheduleReminders(med.id, med.name, med.dosage, times);
    } else {
      await _cancelReminders(med.id, times.length);
    }
  }

  /// Enregistre une prise maintenant.
  Future<void> logIntake(int medicationId) {
    return db.into(db.medicationLogs).insert(MedicationLogsCompanion.insert(
          medicationId: medicationId,
          takenAt: DateTime.now(),
        ));
  }

  /// Nombre de prises enregistrées aujourd'hui, par médicament.
  Stream<Map<int, int>> watchTodayIntakeCounts() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (db.select(db.medicationLogs)
          ..where((l) => l.takenAt.isBiggerOrEqualValue(start))
          ..where((l) => l.takenAt.isSmallerThanValue(end)))
        .watch()
        .map((rows) {
      final counts = <int, int>{};
      for (final r in rows) {
        counts[r.medicationId] = (counts[r.medicationId] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ---------- Notifications ----------

  // ID de notif unique et stable : medicationId * 10 + index de l'heure.
  int _notifId(int medId, int index) => medId * 10 + index;

  Future<void> _scheduleReminders(
      int medId, String name, String dosage, List<String> times) async {
    for (var i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      await Notifications.scheduleDaily(
        id: _notifId(medId, i),
        title: '💊 $name',
        body: dosage.isEmpty ? 'C\'est l\'heure de ta prise.' : 'À prendre : $dosage',
        hour: h,
        minute: m,
      );
    }
  }

  Future<void> _cancelReminders(int medId, int count) async {
    for (var i = 0; i < count; i++) {
      await Notifications.cancel(_notifId(medId, i));
    }
  }

  static List<String> _parseTimes(String raw) =>
      raw.split(',').where((s) => s.trim().isNotEmpty).toList();

  // ---------- Requêtes par période (pour l'export PDF) ----------

  Future<List<SleepEntry>> sleepBetween(DateTime start, DateTime end) {
    return (db.select(db.sleepEntries)
          ..where((s) => s.date.isBetweenValues(start, end))
          ..orderBy([(s) => OrderingTerm(expression: s.date)]))
        .get();
  }

  Future<List<PainEntry>> painBetween(DateTime start, DateTime end) {
    return (db.select(db.painEntries)
          ..where((p) => p.at.isBetweenValues(start, end))
          ..orderBy([(p) => OrderingTerm(expression: p.at)]))
        .get();
  }

  Future<List<MedicationLog>> medLogsBetween(DateTime start, DateTime end) {
    return (db.select(db.medicationLogs)
          ..where((l) => l.takenAt.isBetweenValues(start, end))
          ..orderBy([(l) => OrderingTerm(expression: l.takenAt)]))
        .get();
  }

  Future<List<Medication>> allMedications() {
    return (db.select(db.medications)
          ..orderBy([(m) => OrderingTerm(expression: m.name)]))
        .get();
  }
}
