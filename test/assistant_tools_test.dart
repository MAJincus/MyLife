import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/core/providers.dart';
import 'package:mylife/data/database.dart';
import 'package:mylife/features/assistant/assistant_tools.dart';
import 'package:mylife/features/diet/diet_repository.dart';
import 'package:mylife/features/finance/finance_repository.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('add_transaction crée une dépense avec catégorie', () async {
    final msg = await executeTool(container, 'add_transaction', {
      'amount': 12.0,
      'kind': 'expense',
      'category': 'Alimentation',
      'note': 'Courses',
    });
    expect(msg, contains('12'));

    final txs =
        await container.read(financeRepositoryProvider).watchTransactions().first;
    expect(txs.single.amount, 12.0);
    expect(txs.single.note, 'Courses');
    expect(txs.single.categoryId, isNotNull);
  });

  test('add_weight et log_meal modifient le journal diète', () async {
    await executeTool(container, 'add_weight', {'weight_kg': 78.5});
    await executeTool(container, 'log_meal', {
      'label': 'Banane',
      'kcal': 90,
      'meal_type': 'snack',
    });

    final diet = container.read(dietRepositoryProvider);
    final weights = await diet.watchWeights().first;
    final meals = await diet.watchMealsForDay(DateTime.now()).first;
    expect(weights.single.weightKg, 78.5);
    expect(meals.single.label, 'Banane');
    expect(meals.single.kcal, 90);
  });

  test('log_medication échoue proprement si le médicament n\'existe pas',
      () async {
    final msg =
        await executeTool(container, 'log_medication', {'name': 'Inconnu'});
    expect(msg, contains('Aucun médicament'));
  });
}
