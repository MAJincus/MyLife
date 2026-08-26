import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/data/database.dart';
import 'package:mylife/features/diet/diet_repository.dart';
import 'package:mylife/features/health/health_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('Santé', () {
    test('la durée de sommeil traverse minuit correctement', () async {
      final repo = HealthRepository(db);
      // Couché à 23h, réveil à 7h → 8h.
      final bed = DateTime(2026, 8, 24, 23, 0);
      final wake = DateTime(2026, 8, 25, 7, 0);
      await repo.addSleep(bedTime: bed, wakeTime: wake, quality: 4);

      final entries = await repo.watchSleep().first;
      expect(entries.single.durationMinutes, 8 * 60);
    });

    test('les prises du jour sont comptées par médicament', () async {
      final repo = HealthRepository(db);
      await repo.addMedication(
          name: 'Doliprane', dosage: '1g', times: [], remindersOn: false);
      final meds = await repo.watchMedications().first;
      final id = meds.single.id;

      await repo.logIntake(id);
      await repo.logIntake(id);

      final counts = await repo.watchTodayIntakeCounts().first;
      expect(counts[id], 2);
    });
  });

  group('Diète', () {
    test('les totaux nutritionnels du jour sont agrégés', () async {
      final repo = DietRepository(db);
      final now = DateTime.now();
      await repo.addMeal(
          at: now,
          mealType: 'lunch',
          label: 'Poulet',
          quantityGrams: 150,
          kcal: 250,
          protein: 40);
      await repo.addMeal(
          at: now,
          mealType: 'snack',
          label: 'Pomme',
          quantityGrams: 100,
          kcal: 52,
          carbs: 14);

      final nut = await repo.watchDayNutrition(now).first;
      expect(nut.kcal, 302);
      expect(nut.protein, 40);
      expect(nut.carbs, 14);
    });

    test('le besoin calorique baisse en objectif perte de poids', () {
      final maintain = Calories.dailyTarget(
          sex: 'male',
          age: 30,
          heightCm: 180,
          weightKg: 80,
          goal: 'maintain');
      final lose = Calories.dailyTarget(
          sex: 'male', age: 30, heightCm: 180, weightKg: 80, goal: 'lose');
      expect(lose, lessThan(maintain));
      expect(maintain - lose, 500);
    });
  });
}
