import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite_open;

import '../core/security/secure_store.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    Transactions,
    SavingsGoals,
    SavingsContributions,
    SleepEntries,
    PainEntries,
    Medications,
    MedicationLogs,
    Foods,
    MealEntries,
    WeightEntries,
    ActivityEntries,
    Reminders,
    ChatMessages,
    Profile,
    Accounts,
    NetWorthPoints,
    WaterEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Poches d'épargne pondérées + capacité d'épargne + profil de vie.
            await m.addColumn(savingsGoals, savingsGoals.weight);
            await m.addColumn(savingsGoals, savingsGoals.icon);
            await m.addColumn(profile, profile.savingsCapacity);
            await m.addColumn(profile, profile.adultsCount);
            await m.addColumn(profile, profile.childrenCount);
            await m.addColumn(profile, profile.housingType);
            await m.addColumn(profile, profile.housingStatus);
            await m.addColumn(profile, profile.housingSurfaceM2);
            await m.addColumn(profile, profile.vehiclesCount);
            await m.addColumn(profile, profile.lifeContext);
          }
          if (from < 3) {
            // Patrimoine net + multi-comptes.
            await m.createTable(accounts);
            await m.createTable(netWorthPoints);
          }
          if (from < 4) {
            await m.createTable(waterEntries);
          }
          if (from < 5) {
            await m.addColumn(profile, profile.proteinPerKg);
            await m.addColumn(profile, profile.fatPerKg);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seed() async {
    // Catégories de départ.
    const seedCats = [
      ('Alimentation', 'restaurant', 0xFFEF6C00, 'expense'),
      ('Logement', 'home', 0xFF5D4037, 'expense'),
      ('Transport', 'directions_car', 0xFF1565C0, 'expense'),
      ('Santé', 'local_hospital', 0xFFC62828, 'expense'),
      ('Loisirs', 'sports_esports', 0xFF6A1B9A, 'expense'),
      ('Abonnements', 'subscriptions', 0xFF00838F, 'expense'),
      ('Salaire', 'payments', 0xFF2E7D32, 'income'),
    ];
    for (final c in seedCats) {
      await into(categories).insert(CategoriesCompanion.insert(
        name: c.$1,
        icon: Value(c.$2),
        color: Value(c.$3),
        kind: Value(c.$4),
      ));
    }
    // Profil unique.
    await into(profile).insert(
      const ProfileCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Ouvre la base chiffrée avec une clé stockée dans le keystore/keychain.
  static Future<AppDatabase> open() async {
    // Force le chargement de la librairie SQLCipher au lieu de SQLite standard.
    sqlite_open.open.overrideFor(
      sqlite_open.OperatingSystem.android,
      openCipherOnAndroid,
    );

    final executor = LazyDatabase(() async {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'mylife.db.sqlite'));
      final key = await SecureStore.databaseKey();

      // NB : ouverture en foreground (pas `createInBackground`) : l'override
      // `open.overrideFor` qui force SQLCipher est propre à l'isolate courant
      // et ne se propage pas à un isolate d'arrière-plan.
      return NativeDatabase(
        file,
        setup: (rawDb) {
          // Vérifie qu'on est bien sur SQLCipher et déchiffre.
          final result = rawDb.select('PRAGMA cipher_version;');
          if (result.isEmpty) {
            throw StateError(
              'SQLCipher indisponible : chiffrement impossible.',
            );
          }
          final escaped = key.replaceAll("'", "''");
          rawDb.execute("PRAGMA key = '$escaped';");
        },
      );
    });
    return AppDatabase(executor);
  }
}

/// Ping utilisé au démarrage pour forcer l'ouverture + migration.
extension DbBootstrap on AppDatabase {
  Future<void> warmup() async {
    await customSelect('SELECT 1').get();
  }
}
