import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/security/crypto_box.dart';
import '../../data/database.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

/// Sauvegarde/restauration d'une archive JSON chiffrée de toute la base.
class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  static const formatVersion = 1;

  /// Sérialise toutes les tables puis chiffre avec la passphrase.
  Future<Uint8List> export(String passphrase) async {
    final data = <String, dynamic>{
      'app': 'MyLife',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'categories': await _dump(db.categories),
        'transactions': await _dump(db.transactions),
        'savingsGoals': await _dump(db.savingsGoals),
        'savingsContributions': await _dump(db.savingsContributions),
        'sleepEntries': await _dump(db.sleepEntries),
        'painEntries': await _dump(db.painEntries),
        'medications': await _dump(db.medications),
        'medicationLogs': await _dump(db.medicationLogs),
        'foods': await _dump(db.foods),
        'mealEntries': await _dump(db.mealEntries),
        'weightEntries': await _dump(db.weightEntries),
        'activityEntries': await _dump(db.activityEntries),
        'reminders': await _dump(db.reminders),
        'chatMessages': await _dump(db.chatMessages),
        'profile': await _dump(db.profile),
      },
    };
    return CryptoBox.encryptString(jsonEncode(data), passphrase);
  }

  /// Déchiffre l'archive et remplace tout le contenu de la base.
  Future<void> import(Uint8List bytes, String passphrase) async {
    final json = CryptoBox.decryptToString(bytes, passphrase);
    final data = jsonDecode(json) as Map<String, dynamic>;
    if (data['app'] != 'MyLife') {
      throw CryptoException('Ce fichier n\'est pas une sauvegarde MyLife.');
    }
    final tables = data['tables'] as Map<String, dynamic>;

    await db.transaction(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      // On vide toutes les tables.
      for (final t in db.allTables) {
        await db.delete(t).go();
      }

      // Réinsertion dans l'ordre des dépendances (parents avant enfants).
      await _load(db.categories, tables['categories'],
          (m) => Category.fromJson(m));
      await _load(db.savingsGoals, tables['savingsGoals'],
          (m) => SavingsGoal.fromJson(m));
      await _load(db.medications, tables['medications'],
          (m) => Medication.fromJson(m));
      await _load(db.foods, tables['foods'], (m) => Food.fromJson(m));
      await _load(db.transactions, tables['transactions'],
          (m) => Transaction.fromJson(m));
      await _load(db.savingsContributions, tables['savingsContributions'],
          (m) => SavingsContribution.fromJson(m));
      await _load(db.sleepEntries, tables['sleepEntries'],
          (m) => SleepEntry.fromJson(m));
      await _load(db.painEntries, tables['painEntries'],
          (m) => PainEntry.fromJson(m));
      await _load(db.medicationLogs, tables['medicationLogs'],
          (m) => MedicationLog.fromJson(m));
      await _load(db.mealEntries, tables['mealEntries'],
          (m) => MealEntry.fromJson(m));
      await _load(db.weightEntries, tables['weightEntries'],
          (m) => WeightEntry.fromJson(m));
      await _load(db.activityEntries, tables['activityEntries'],
          (m) => ActivityEntry.fromJson(m));
      await _load(
          db.reminders, tables['reminders'], (m) => Reminder.fromJson(m));
      await _load(db.chatMessages, tables['chatMessages'],
          (m) => ChatMessage.fromJson(m));
      await _load(
          db.profile, tables['profile'], (m) => ProfileData.fromJson(m));

      await db.customStatement('PRAGMA foreign_keys = ON');
    });
  }

  Future<List<Map<String, dynamic>>> _dump(TableInfo table) async {
    final rows = await db.select(table).get();
    return rows.map((r) => (r as DataClass).toJson()).toList();
  }

  Future<void> _load<T extends Table, D>(
    TableInfo<T, D> table,
    dynamic rows,
    D Function(Map<String, dynamic>) fromJson,
  ) async {
    if (rows is! List) return;
    for (final row in rows) {
      final entity = fromJson(row as Map<String, dynamic>);
      await db
          .into(table)
          .insert(entity as Insertable<D>, mode: InsertMode.insertOrReplace);
    }
  }
}
