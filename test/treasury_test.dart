import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/features/finance/recurring.dart';
import 'package:mylife/features/finance/treasury.dart';

void main() {
  Recurring rec(String label, double amount) => Recurring(
        label: label,
        typicalAmount: amount,
        frequency: 'monthly',
        occurrences: 3,
        lastDate: DateTime(2026, 8, 1),
      );

  test('projette le solde de fin de mois', () {
    // 15 août : 16 jours restants (mois de 31 j).
    final f = computeForecast(
      startBalance: 1000,
      hasStartBalance: true,
      recurring: [rec('SALAIRE', 2000), rec('LOYER', -800)],
      seenThisMonth: {}, // rien encore passé ce mois
      avgDailyVariable: 20,
      now: DateTime(2026, 8, 15),
    );
    expect(f.remainingDays, 16);
    expect(f.expectedIncome, 2000);
    expect(f.expectedCharges, 800);
    expect(f.expectedVariable, 320); // 20 × 16
    // 1000 + 2000 − 800 − 320
    expect(f.endBalance, 1880);
    expect(f.netChange, 880);
  });

  test('ignore les récurrents déjà passés ce mois', () {
    final f = computeForecast(
      startBalance: 500,
      hasStartBalance: true,
      recurring: [rec('SALAIRE', 2000), rec('LOYER', -800)],
      seenThisMonth: {'SALAIRE', 'LOYER'}, // déjà tombés
      avgDailyVariable: 10,
      now: DateTime(2026, 8, 20),
    );
    expect(f.expectedIncome, 0);
    expect(f.expectedCharges, 0);
    // seulement les dépenses variables restantes (11 j × 10)
    expect(f.expectedVariable, 110);
    expect(f.endBalance, 390);
  });

  test('sans solde de départ, expose la variation nette', () {
    final f = computeForecast(
      startBalance: 0,
      hasStartBalance: false,
      recurring: [rec('SALAIRE', 2000), rec('LOYER', -800)],
      seenThisMonth: {},
      avgDailyVariable: 0,
      now: DateTime(2026, 8, 31),
    );
    expect(f.hasStartBalance, isFalse);
    expect(f.remainingDays, 0);
    expect(f.netChange, 1200);
  });
}
