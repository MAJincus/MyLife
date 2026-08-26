import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/data/database.dart';
import 'package:mylife/features/finance/finance_repository.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FinanceRepository(db);
  });

  tearDown(() => db.close());

  test('les catégories de départ sont créées', () async {
    final cats = await repo.watchCategories().first;
    expect(cats, isNotEmpty);
    expect(cats.any((c) => c.name == 'Alimentation'), isTrue);
  });

  test('le résumé du mois agrège revenus et dépenses', () async {
    final now = DateTime.now();
    await repo.addTransaction(TransactionsCompanion.insert(
      amount: 100,
      kind: const Value('income'),
      date: now,
    ));
    await repo.addTransaction(TransactionsCompanion.insert(
      amount: 30,
      kind: const Value('expense'),
      date: now,
    ));

    final summary = await repo.watchMonthSummary(now).first;
    expect(summary.income, 100);
    expect(summary.expense, 30);
    expect(summary.balance, 70);
  });

  test('une contribution met à jour le montant épargné', () async {
    final goalId = await repo.addGoal(SavingsGoalsCompanion.insert(
      name: 'Vacances',
      targetAmount: const Value(1000),
    ));
    await repo.contribute(goalId, 250);

    final goals = await repo.watchGoals().first;
    final goal = goals.firstWhere((g) => g.id == goalId);
    expect(goal.currentAmount, 250);
  });

  test('la répartition par catégorie trie par montant décroissant', () async {
    final cats = await repo.watchCategories().first;
    final alim = cats.firstWhere((c) => c.name == 'Alimentation');
    final transport = cats.firstWhere((c) => c.name == 'Transport');
    final now = DateTime.now();

    await repo.addTransaction(TransactionsCompanion.insert(
      amount: 20,
      kind: const Value('expense'),
      categoryId: Value(transport.id),
      date: now,
    ));
    await repo.addTransaction(TransactionsCompanion.insert(
      amount: 80,
      kind: const Value('expense'),
      categoryId: Value(alim.id),
      date: now,
    ));

    final spend = await repo.watchSpendByCategory(now).first;
    expect(spend.first.category.name, 'Alimentation');
    expect(spend.first.total, 80);
  });
}
