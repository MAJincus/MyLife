import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/providers.dart';
import '../../data/database.dart';

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  return AgendaRepository(ref.watch(databaseProvider));
});

class AgendaRepository {
  AgendaRepository(this.db);
  final AppDatabase db;

  // Espace d'ID de notification distinct de celui des médicaments.
  static const _notifBase = 500000;
  int _notifId(int reminderId) => _notifBase + reminderId;

  /// Rappels à venir non terminés (triés par échéance croissante).
  Stream<List<Reminder>> watchUpcoming() {
    return (db.select(db.reminders)
          ..where((r) => r.done.equals(false))
          ..orderBy([(r) => OrderingTerm(expression: r.dueAt)]))
        .watch();
  }

  /// Rappels terminés (récents d'abord).
  Stream<List<Reminder>> watchDone({int limit = 30}) {
    return (db.select(db.reminders)
          ..where((r) => r.done.equals(true))
          ..orderBy([
            (r) => OrderingTerm(expression: r.dueAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> addReminder({
    required String title,
    required String note,
    required DateTime dueAt,
    required String repeatRule,
  }) async {
    final id = await db.into(db.reminders).insert(RemindersCompanion.insert(
          title: title,
          note: Value(note),
          dueAt: dueAt,
          repeatRule: Value(repeatRule),
        ));
    final notifId = _notifId(id);
    await (db.update(db.reminders)..where((r) => r.id.equals(id)))
        .write(RemindersCompanion(notificationId: Value(notifId)));
    await Notifications.scheduleReminder(
      id: notifId,
      title: title,
      body: note.isEmpty ? 'Rappel' : note,
      when: dueAt,
      repeatRule: repeatRule,
    );
  }

  Future<void> setDone(Reminder r, bool done) async {
    await (db.update(db.reminders)..where((x) => x.id.equals(r.id)))
        .write(RemindersCompanion(done: Value(done)));
    // Une fois fait, on annule la notification en attente.
    if (done && r.notificationId != null) {
      await Notifications.cancel(r.notificationId!);
    } else if (!done) {
      await Notifications.scheduleReminder(
        id: r.notificationId ?? _notifId(r.id),
        title: r.title,
        body: r.note.isEmpty ? 'Rappel' : r.note,
        when: r.dueAt,
        repeatRule: r.repeatRule,
      );
    }
  }

  Future<void> deleteReminder(Reminder r) async {
    if (r.notificationId != null) {
      await Notifications.cancel(r.notificationId!);
    }
    await (db.delete(db.reminders)..where((x) => x.id.equals(r.id))).go();
  }
}
