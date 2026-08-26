import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/database.dart';

final dietRepositoryProvider = Provider<DietRepository>((ref) {
  return DietRepository(ref.watch(databaseProvider));
});

/// Totaux nutritionnels d'une journée.
class DayNutrition {
  DayNutrition({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}

class DietRepository {
  DietRepository(this.db);
  final AppDatabase db;

  // ---------- Repas ----------

  Stream<List<MealEntry>> watchMealsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (db.select(db.mealEntries)
          ..where((m) => m.at.isBiggerOrEqualValue(start))
          ..where((m) => m.at.isSmallerThanValue(end))
          ..orderBy([(m) => OrderingTerm(expression: m.at)]))
        .watch();
  }

  Stream<DayNutrition> watchDayNutrition(DateTime day) {
    return watchMealsForDay(day).map((meals) {
      double k = 0, p = 0, c = 0, f = 0;
      for (final m in meals) {
        k += m.kcal;
        p += m.protein;
        c += m.carbs;
        f += m.fat;
      }
      return DayNutrition(kcal: k, protein: p, carbs: c, fat: f);
    });
  }

  Future<void> addMeal({
    required DateTime at,
    required String mealType,
    required String label,
    required double quantityGrams,
    required double kcal,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    int? foodId,
  }) {
    return db.into(db.mealEntries).insert(MealEntriesCompanion.insert(
          at: at,
          mealType: Value(mealType),
          label: Value(label),
          quantityGrams: Value(quantityGrams),
          kcal: kcal,
          protein: Value(protein),
          carbs: Value(carbs),
          fat: Value(fat),
          foodId: Value(foodId),
        ));
  }

  Future<void> deleteMeal(int id) =>
      (db.delete(db.mealEntries)..where((m) => m.id.equals(id))).go();

  // ---------- Base d'aliments ----------

  Stream<List<Food>> watchFoods() {
    return (db.select(db.foods)
          ..orderBy([
            (f) => OrderingTerm(expression: f.favorite, mode: OrderingMode.desc),
            (f) => OrderingTerm(expression: f.name),
          ]))
        .watch();
  }

  Future<int> addFood(FoodsCompanion food) => db.into(db.foods).insert(food);

  // ---------- Poids ----------

  Stream<List<WeightEntry>> watchWeights({int limit = 90}) {
    return (db.select(db.weightEntries)
          ..orderBy([
            (w) => OrderingTerm(expression: w.date, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> addWeight(double kg, {DateTime? date, String note = ''}) {
    return db.into(db.weightEntries).insert(WeightEntriesCompanion.insert(
          date: date ?? DateTime.now(),
          weightKg: kg,
          note: Value(note),
        ));
  }

  Future<void> deleteWeight(int id) =>
      (db.delete(db.weightEntries)..where((w) => w.id.equals(id))).go();

  // ---------- Activité ----------

  Stream<List<ActivityEntry>> watchActivitiesForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (db.select(db.activityEntries)
          ..where((a) => a.at.isBiggerOrEqualValue(start))
          ..where((a) => a.at.isSmallerThanValue(end))
          ..orderBy([(a) => OrderingTerm(expression: a.at)]))
        .watch();
  }

  Future<void> addActivity({
    required String type,
    required int durationMinutes,
    required double kcalBurned,
    DateTime? at,
  }) {
    return db.into(db.activityEntries).insert(ActivityEntriesCompanion.insert(
          at: at ?? DateTime.now(),
          type: Value(type),
          durationMinutes: Value(durationMinutes),
          kcalBurned: Value(kcalBurned),
        ));
  }

  Future<void> deleteActivity(int id) =>
      (db.delete(db.activityEntries)..where((a) => a.id.equals(id))).go();

  // ---------- Requêtes par période (corrélations) ----------

  Future<List<MealEntry>> mealsBetween(DateTime start, DateTime end) {
    return (db.select(db.mealEntries)
          ..where((m) => m.at.isBetweenValues(start, end)))
        .get();
  }

  Future<List<ActivityEntry>> activitiesBetween(DateTime start, DateTime end) {
    return (db.select(db.activityEntries)
          ..where((a) => a.at.isBetweenValues(start, end)))
        .get();
  }

  Future<List<WeightEntry>> weightsBetween(DateTime start, DateTime end) {
    return (db.select(db.weightEntries)
          ..where((w) => w.date.isBetweenValues(start, end)))
        .get();
  }

  // ---------- Profil / objectif ----------

  Stream<ProfileData> watchProfile() {
    return (db.select(db.profile)..where((p) => p.id.equals(1))).watchSingle();
  }

  Future<void> updateProfile(ProfileCompanion companion) {
    return (db.update(db.profile)..where((p) => p.id.equals(1)))
        .write(companion);
  }
}

/// Calcul du besoin calorique journalier (Mifflin-St Jeor + activité + objectif).
class Calories {
  /// Métabolisme de base.
  static double bmr({
    required String sex,
    required int age,
    required int heightCm,
    required double weightKg,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    if (sex == 'male') return base + 5;
    if (sex == 'female') return base - 161;
    return base - 78; // moyenne
  }

  /// Besoin quotidien estimé pour un niveau d'activité léger + objectif.
  static int dailyTarget({
    required String sex,
    required int age,
    required int heightCm,
    required double weightKg,
    required String goal, // lose | maintain | gain
  }) {
    final maintenance =
        bmr(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg) * 1.4;
    final adjusted = switch (goal) {
      'lose' => maintenance - 500,
      'gain' => maintenance + 300,
      _ => maintenance,
    };
    return adjusted.round();
  }
}
