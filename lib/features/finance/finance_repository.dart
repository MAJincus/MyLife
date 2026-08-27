import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/database.dart';
import 'finance_history.dart';
import 'recurring.dart';
import 'treasury.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(databaseProvider));
});

/// Total de dépenses agrégé par catégorie sur une période.
class CategorySpend {
  CategorySpend(this.category, this.total);
  final Category category;
  final double total;
}

class MonthSummary {
  MonthSummary({required this.income, required this.expense});
  final double income;
  final double expense;
  double get balance => income - expense;
}

/// Transaction à importer (montant signé : <0 = dépense).
class ImportTx {
  ImportTx({
    required this.date,
    required this.label,
    required this.amount,
    this.categoryId,
  });
  final DateTime date;
  final String label;
  final double amount;
  final int? categoryId;
}

class ImportResult {
  ImportResult({required this.added, required this.skipped});
  final int added;
  final int skipped;
}

class FinanceRepository {
  FinanceRepository(this.db);
  final AppDatabase db;

  // ---------- Catégories ----------

  Stream<List<Category>> watchCategories() {
    return (db.select(db.categories)
          ..where((c) => c.archived.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  Future<int> addCategory(CategoriesCompanion c) =>
      db.into(db.categories).insert(c);

  // ---------- Transactions ----------

  Stream<List<Transaction>> watchTransactions({int limit = 200}) {
    return (db.select(db.transactions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<int> addTransaction(TransactionsCompanion t) =>
      db.into(db.transactions).insert(t);

  Future<void> deleteTransaction(int id) =>
      (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();

  Future<List<Transaction>> expensesBetween(DateTime start, DateTime end) {
    return (db.select(db.transactions)
          ..where((t) => t.kind.equals('expense'))
          ..where((t) => t.date.isBetweenValues(start, end)))
        .get();
  }

  /// Importe des transactions signées en ignorant les doublons
  /// (même jour + même montant + même libellé).
  Future<ImportResult> importTransactions(List<ImportTx> items) async {
    final existing = await db.select(db.transactions).get();
    String hash(DateTime d, double signed, String note) =>
        '${d.year}-${d.month}-${d.day}|${signed.toStringAsFixed(2)}|'
        '${note.toLowerCase().trim()}';

    final seen = <String>{
      for (final t in existing)
        hash(t.date, t.kind == 'expense' ? -t.amount : t.amount, t.note),
    };

    var added = 0, skipped = 0;
    await db.batch((b) {
      for (final it in items) {
        final h = hash(it.date, it.amount, it.label);
        if (seen.contains(h)) {
          skipped++;
          continue;
        }
        seen.add(h);
        b.insert(
          db.transactions,
          TransactionsCompanion.insert(
            amount: it.amount.abs(),
            kind: Value(it.amount < 0 ? 'expense' : 'income'),
            categoryId: Value(it.categoryId),
            date: it.date,
            note: Value(it.label),
          ),
        );
        added++;
      }
    });
    return ImportResult(added: added, skipped: skipped);
  }

  /// Résumé revenus/dépenses pour le mois de [ref].
  Stream<MonthSummary> watchMonthSummary(DateTime ref) {
    final start = DateTime(ref.year, ref.month, 1);
    final end = DateTime(ref.year, ref.month + 1, 1);
    final query = db.select(db.transactions)
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerThanValue(end));
    return query.watch().map((rows) {
      double income = 0, expense = 0;
      for (final t in rows) {
        if (t.kind == 'income') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      return MonthSummary(income: income, expense: expense);
    });
  }

  /// Dépenses par catégorie pour le mois de [ref] (tri décroissant).
  Stream<List<CategorySpend>> watchSpendByCategory(DateTime ref) {
    final start = DateTime(ref.year, ref.month, 1);
    final end = DateTime(ref.year, ref.month + 1, 1);

    final catStream = watchCategories();
    final txStream = (db.select(db.transactions)
          ..where((t) => t.kind.equals('expense'))
          ..where((t) => t.date.isBiggerOrEqualValue(start))
          ..where((t) => t.date.isSmallerThanValue(end)))
        .watch();

    return catStream.combineWith(txStream, (cats, txs) {
      final byCat = <int?, double>{};
      for (final t in txs) {
        byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
      }
      final result = <CategorySpend>[];
      for (final c in cats) {
        final total = byCat[c.id] ?? 0;
        if (total > 0) result.add(CategorySpend(c, total));
      }
      result.sort((a, b) => b.total.compareTo(a.total));
      return result;
    });
  }

  // ---------- Épargne ----------

  Stream<List<SavingsGoal>> watchGoals() {
    return (db.select(db.savingsGoals)
          ..where((g) => g.archived.equals(false))
          ..orderBy([(g) => OrderingTerm(expression: g.name)]))
        .watch();
  }

  Future<int> addGoal(SavingsGoalsCompanion g) =>
      db.into(db.savingsGoals).insert(g);

  Future<void> updateGoal(int id, SavingsGoalsCompanion patch) =>
      (db.update(db.savingsGoals)..where((g) => g.id.equals(id))).write(patch);

  Future<void> archiveGoal(int id) => (db.update(db.savingsGoals)
        ..where((g) => g.id.equals(id)))
      .write(const SavingsGoalsCompanion(archived: Value(true)));

  /// Crée les 6 poches types si l'utilisateur n'en a aucune.
  Future<void> seedDefaultPockets() async {
    final existing = await watchGoals().first;
    if (existing.isNotEmpty) return;
    const pockets = [
      ('Voyages', 'flight', 0xFF1565C0, 3),
      ('Études enfants', 'school', 0xFF6A1B9A, 5),
      ('Permis', 'directions_car', 0xFF00838F, 4),
      ('Placements (foncier)', 'forest', 0xFF2E7D32, 4),
      ('Sécurité', 'shield', 0xFFC62828, 5),
      ('Fun', 'celebration', 0xFFEF6C00, 2),
    ];
    for (final p in pockets) {
      await addGoal(SavingsGoalsCompanion.insert(
        name: p.$1,
        // Explicite : les bases migrées n'ont pas de DEFAULT SQL sur cette colonne.
        targetAmount: const Value(0),
        icon: Value(p.$2),
        color: Value(p.$3),
        weight: Value(p.$4),
      ));
    }
  }

  /// Capacité d'épargne mensuelle estimée = moyenne (revenus − dépenses)
  /// sur les [months] derniers mois.
  Future<double> averageMonthlySavings({int months = 3}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start)))
        .get();
    double income = 0, expense = 0;
    for (final t in rows) {
      if (t.kind == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final avg = (income - expense) / months;
    return avg > 0 ? avg : 0;
  }

  /// Détecte les revenus/charges récurrents sur les [months] derniers mois.
  Future<RecurringSummary> recurringSummary({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start)))
        .get();
    final lite = [
      for (final t in rows)
        TxLite(
          date: t.date,
          amount: t.kind == 'expense' ? -t.amount : t.amount,
          label: t.note,
        ),
    ];
    return RecurringSummary(detectRecurring(lite, minOccurrences: 2));
  }

  /// Prévision de trésorerie de fin de mois à partir d'un solde de départ.
  Future<TreasuryForecast> treasuryForecast(
      double startBalance, bool hasStartBalance) async {
    final now = DateTime.now();
    final rec = await recurringSummary();

    // Récurrents déjà passés ce mois-ci (leurs montants ne sont plus à venir).
    final startMonth = DateTime(now.year, now.month, 1);
    final monthTxs = await (db.select(db.transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(startMonth)))
        .get();
    final seenLabels = monthTxs.map((t) => normalizeLabel(t.note)).toSet();
    final seenRec =
        rec.items.map((r) => r.label).where(seenLabels.contains).toSet();

    // Dépense variable = dépense mensuelle moyenne − charges récurrentes.
    final avgMonthlyExpense = await _avgMonthlyExpense(3);
    final variableMonthly =
        (avgMonthlyExpense - rec.monthlyCharges).clamp(0, double.infinity);
    final avgDaily = variableMonthly / 30.0;

    return computeForecast(
      startBalance: startBalance,
      hasStartBalance: hasStartBalance,
      recurring: rec.items,
      seenThisMonth: seenRec,
      avgDailyVariable: avgDaily,
      now: now,
    );
  }

  /// Statistiques mensuelles (revenus/dépenses/solde/taux d'épargne).
  Future<List<MonthStat>> monthlyStats({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start)))
        .get();
    final txs = rows.map<TxRow>(
        (t) => (date: t.date, amount: t.amount, isIncome: t.kind == 'income'));
    return monthlyStatsFrom(txs, now: now, months: months);
  }

  Future<double> _avgMonthlyExpense(int months) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start))
          ..where((t) => t.kind.equals('expense')))
        .get();
    final total = rows.fold<double>(0, (s, t) => s + t.amount);
    return total / months;
  }

  Stream<ProfileData> watchProfile() =>
      (db.select(db.profile)..where((p) => p.id.equals(1))).watchSingle();

  Future<void> updateProfile(ProfileCompanion patch) =>
      (db.update(db.profile)..where((p) => p.id.equals(1))).write(patch);

  /// Ajoute une contribution et met à jour le montant courant de l'objectif.
  Future<void> contribute(int goalId, double amount, {String note = ''}) async {
    await db.transaction(() async {
      await db.into(db.savingsContributions).insert(
            SavingsContributionsCompanion.insert(
              goalId: goalId,
              amount: amount,
              date: DateTime.now(),
              note: Value(note),
            ),
          );
      final goal = await (db.select(db.savingsGoals)
            ..where((g) => g.id.equals(goalId)))
          .getSingle();
      await (db.update(db.savingsGoals)..where((g) => g.id.equals(goalId)))
          .write(SavingsGoalsCompanion(
        currentAmount: Value(goal.currentAmount + amount),
      ));
    });
  }
}

/// Combine deux streams en recalculant à chaque émission de l'un ou l'autre.
extension _Combine<A> on Stream<A> {
  Stream<R> combineWith<B, R>(Stream<B> other, R Function(A, B) combine) {
    late A lastA;
    late B lastB;
    var hasA = false, hasB = false;
    final controller = StreamController<R>();

    void emit() {
      if (hasA && hasB) controller.add(combine(lastA, lastB));
    }

    final subA = listen((a) {
      lastA = a;
      hasA = true;
      emit();
    });
    final subB = other.listen((b) {
      lastB = b;
      hasB = true;
      emit();
    });
    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };
    return controller.stream;
  }
}
