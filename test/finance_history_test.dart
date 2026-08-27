import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/features/finance/finance_history.dart';

void main() {
  TxRow tx(int y, int m, double amount, bool income) =>
      (date: DateTime(y, m, 15), amount: amount, isIncome: income);

  test('agrège revenus/dépenses par mois et remplit les mois vides', () {
    final now = DateTime(2026, 8, 20);
    final txs = [
      tx(2026, 8, 2000, true),
      tx(2026, 8, 500, false),
      tx(2026, 8, 300, false),
      tx(2026, 6, 1000, true), // il y a 2 mois
    ];
    final stats = monthlyStatsFrom(txs, now: now, months: 6);
    expect(stats.length, 6);
    // Dernier = août.
    final aout = stats.last;
    expect(aout.month, 8);
    expect(aout.income, 2000);
    expect(aout.expense, 800);
    expect(aout.balance, 1200);
    expect(aout.savingsRate, closeTo(0.6, 1e-9));
    // Juillet = vide.
    final juillet = stats[stats.length - 2];
    expect(juillet.month, 7);
    expect(juillet.income, 0);
    expect(juillet.expense, 0);
    expect(juillet.savingsRate, 0);
  });

  test('taux d\'épargne nul si pas de revenus', () {
    final s = monthlyStatsFrom([tx(2026, 8, 100, false)],
        now: DateTime(2026, 8, 1), months: 1);
    expect(s.single.savingsRate, 0);
    expect(s.single.balance, -100);
  });

  test('relativeDelta', () {
    expect(relativeDelta(120, 100), closeTo(0.2, 1e-9));
    expect(relativeDelta(80, 100), closeTo(-0.2, 1e-9));
    expect(relativeDelta(50, 0), isNull);
  });
}
