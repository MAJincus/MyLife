import 'package:drift/drift.dart';

// ===================== FINANCES =====================

/// Catégories de dépenses/revenus (Alimentation, Loyer, Salaire...).
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF6750A4))();

  /// 'expense' ou 'income'
  TextColumn get kind => text().withDefault(const Constant('expense'))();

  /// Budget mensuel indicatif (null = pas de budget).
  RealColumn get monthlyBudget => real().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();

  /// 'expense' ou 'income'
  TextColumn get kind => text().withDefault(const Constant('expense'))();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// Objectifs d'épargne par projet (vacances, voiture, matelas de sécurité...).
class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// 0 = pas d'objectif chiffré (poche "ouverte" type Sécurité/Fun).
  RealColumn get targetAmount => real().withDefault(const Constant(0))();
  RealColumn get currentAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF2E7D32))();

  /// Poids d'importance 1..5 pour la répartition mensuelle.
  IntColumn get weight => integer().withDefault(const Constant(3))();
  TextColumn get icon => text().withDefault(const Constant('savings'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class SavingsContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId =>
      integer().references(SavingsGoals, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

// ===================== SANTÉ =====================

class SleepEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nuit rattachée (date du réveil).
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get bedTime => dateTime()();
  DateTimeColumn get wakeTime => dateTime()();
  IntColumn get durationMinutes => integer()();

  /// Qualité ressentie 1..5
  IntColumn get quality => integer().withDefault(const Constant(3))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class PainEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();
  TextColumn get location => text().withDefault(const Constant(''))();

  /// Intensité 0..10
  IntColumn get intensity => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get dosage => text().withDefault(const Constant(''))();

  /// Heures de prise sérialisées "08:00,20:00".
  TextColumn get scheduleTimes => text().withDefault(const Constant(''))();
  BoolColumn get remindersOn => boolean().withDefault(const Constant(true))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class MedicationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId =>
      integer().references(Medications, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get takenAt => dateTime()();
}

// ===================== DIÈTE / NUTRITION =====================

/// Base d'aliments (valeurs pour 100 g).
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get kcalPer100 => real()();
  RealColumn get proteinPer100 => real().withDefault(const Constant(0))();
  RealColumn get carbsPer100 => real().withDefault(const Constant(0))();
  RealColumn get fatPer100 => real().withDefault(const Constant(0))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
}

class MealEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();

  /// 'breakfast' | 'lunch' | 'dinner' | 'snack'
  TextColumn get mealType => text().withDefault(const Constant('snack'))();
  IntColumn get foodId => integer().nullable().references(Foods, #id)();
  TextColumn get label => text().withDefault(const Constant(''))();
  RealColumn get quantityGrams => real().withDefault(const Constant(100))();
  RealColumn get kcal => real()();
  RealColumn get protein => real().withDefault(const Constant(0))();
  RealColumn get carbs => real().withDefault(const Constant(0))();
  RealColumn get fat => real().withDefault(const Constant(0))();
}

class WeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class ActivityEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();
  TextColumn get type => text().withDefault(const Constant(''))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  RealColumn get kcalBurned => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

// ===================== AGENDA =====================

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get dueAt => dateTime()();

  /// 'none' | 'daily' | 'weekly' | 'monthly'
  TextColumn get repeatRule => text().withDefault(const Constant('none'))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// ID de notification locale planifiée (pour annulation).
  IntColumn get notificationId => integer().nullable()();
}

// ===================== ASSISTANT =====================

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'user' | 'assistant'
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
}

// ===================== PATRIMOINE =====================

/// Un compte ou poste de patrimoine (actif ou passif).
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// 'asset' (actif) | 'liability' (passif/dette)
  TextColumn get kind => text().withDefault(const Constant('asset'))();

  /// Sous-type : 'checking' | 'savings' | 'cash' | 'investment' |
  /// 'property' | 'loan' | 'credit' | 'other'
  TextColumn get type => text().withDefault(const Constant('checking'))();

  /// Solde courant (toujours positif ; le signe vient de [kind]).
  RealColumn get balance => real().withDefault(const Constant(0))();

  /// Compte liquide pris en compte dans la prévision de trésorerie.
  BoolColumn get liquid => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().withDefault(const Constant(0xFF1565C0))();
  TextColumn get icon => text().withDefault(const Constant('account_balance'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Point d'historique du patrimoine net (pour la courbe).
class NetWorthPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
}

// ===================== PROFIL =====================

/// Une seule ligne (id=1) : objectifs diète, données perso.
class Profile extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get heightCm => integer().nullable()();
  IntColumn get birthYear => integer().nullable()();

  /// 'male' | 'female' | 'other'
  TextColumn get sex => text().withDefault(const Constant('other'))();

  /// Objectif calorique journalier.
  IntColumn get dailyKcalTarget => integer().nullable()();

  /// 'lose' | 'maintain' | 'gain'
  TextColumn get dietGoal => text().withDefault(const Constant('maintain'))();
  RealColumn get targetWeightKg => real().nullable()();

  /// Capacité d'épargne mensuelle saisie manuellement (null = auto-calcul).
  RealColumn get savingsCapacity => real().nullable()();

  // --- Profil de vie (contexte pour l'analyse financière par l'IA) ---
  IntColumn get adultsCount => integer().nullable()();
  IntColumn get childrenCount => integer().nullable()();

  /// 'apartment' | 'house' | ''
  TextColumn get housingType => text().withDefault(const Constant(''))();

  /// 'owner' | 'renter' | ''
  TextColumn get housingStatus => text().withDefault(const Constant(''))();
  IntColumn get housingSurfaceM2 => integer().nullable()();
  IntColumn get vehiclesCount => integer().nullable()();

  /// Notes libres sur la situation (chauffage, ville, animaux…).
  TextColumn get lifeContext => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
