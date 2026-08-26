import 'recurring.dart';

/// Prévision de trésorerie de fin de mois.
class TreasuryForecast {
  TreasuryForecast({
    required this.startBalance,
    required this.expectedIncome,
    required this.expectedCharges,
    required this.expectedVariable,
    required this.remainingDays,
    required this.hasStartBalance,
  });

  final double startBalance;
  final double expectedIncome; // revenus récurrents restants ce mois
  final double expectedCharges; // charges récurrentes restantes ce mois
  final double expectedVariable; // dépenses variables restantes estimées
  final int remainingDays;
  final bool hasStartBalance;

  /// Variation nette attendue d'ici la fin du mois.
  double get netChange => expectedIncome - expectedCharges - expectedVariable;

  /// Solde projeté en fin de mois.
  double get endBalance => startBalance + netChange;

  /// Ce qu'on peut encore dépenser par jour en gardant un solde ≥ 0.
  double get safeToSpendPerDay {
    if (remainingDays <= 0) return 0;
    final buffer = startBalance + expectedIncome - expectedCharges;
    return buffer > 0 ? buffer / remainingDays : 0;
  }
}

/// Calcule la prévision de fin de mois.
///
/// [seenThisMonth] = libellés normalisés des récurrents déjà passés ce mois
/// (leurs montants ne sont plus « à venir »).
TreasuryForecast computeForecast({
  required double startBalance,
  required bool hasStartBalance,
  required List<Recurring> recurring,
  required Set<String> seenThisMonth,
  required double avgDailyVariable,
  required DateTime now,
}) {
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final remainingDays = (lastDay - now.day).clamp(0, 31);

  double income = 0, charges = 0;
  for (final r in recurring) {
    if (seenThisMonth.contains(r.label)) continue; // déjà passé ce mois
    if (r.isIncome) {
      income += r.monthlyEquivalent;
    } else {
      charges += r.monthlyEquivalent.abs();
    }
  }

  final variable = (avgDailyVariable * remainingDays).clamp(0, double.infinity);

  return TreasuryForecast(
    startBalance: startBalance,
    expectedIncome: income,
    expectedCharges: charges,
    expectedVariable: variable.toDouble(),
    remainingDays: remainingDays,
    hasStartBalance: hasStartBalance,
  );
}
