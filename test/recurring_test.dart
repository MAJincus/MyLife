import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/features/finance/recurring.dart';

void main() {
  group('normalizeLabel', () {
    test('retire chiffres, ponctuation et mots parasites', () {
      expect(normalizeLabel('PAIEMENT CB NETFLIX.COM 25/08 1234'), 'NETFLIX COM');
      expect(normalizeLabel('PRLV SEPA EDF FACTURE 0012'), 'EDF');
      expect(normalizeLabel('VIREMENT SALAIRE AOUT'), 'SALAIRE AOUT');
    });
  });

  TxLite tx(String label, double amount, int month) =>
      TxLite(date: DateTime(2026, month, 5), amount: amount, label: label);

  test('détecte un abonnement mensuel', () {
    final txs = [
      tx('PRLV NETFLIX 111', -13.49, 6),
      tx('PRLV NETFLIX 222', -13.49, 7),
      tx('PRLV NETFLIX 333', -13.49, 8),
    ];
    final rec = detectRecurring(txs, minOccurrences: 3);
    expect(rec.length, 1);
    expect(rec.first.label, 'NETFLIX');
    expect(rec.first.typicalAmount, -13.49);
    expect(rec.first.frequency, 'monthly');
    expect(rec.first.isIncome, isFalse);
  });

  test('ignore les opérations sur un seul mois', () {
    final txs = [
      tx('CARREFOUR', -20, 8),
      tx('CARREFOUR', -25, 8),
    ];
    expect(detectRecurring(txs, minOccurrences: 2), isEmpty);
  });

  test('reste à vivre = revenus récurrents − charges récurrentes', () {
    final txs = [
      tx('SALAIRE', 2000, 6),
      tx('SALAIRE', 2000, 7),
      tx('SALAIRE', 2000, 8),
      tx('LOYER', -800, 6),
      tx('LOYER', -800, 7),
      tx('LOYER', -800, 8),
      tx('EDF', -60, 6),
      tx('EDF', -60, 7),
      tx('EDF', -60, 8),
    ];
    final summary = RecurringSummary(detectRecurring(txs, minOccurrences: 3));
    expect(summary.monthlyIncome, 2000);
    expect(summary.monthlyCharges, 860);
    expect(summary.leftToLive, 1140);
    expect(summary.charges.length, 2);
    expect(summary.incomes.length, 1);
  });
}
