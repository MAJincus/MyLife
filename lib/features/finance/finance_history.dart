import 'package:intl/intl.dart';

/// Statistiques financières d'un mois.
class MonthStat {
  MonthStat({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });
  final int year;
  final int month;
  final double income;
  final double expense;

  double get balance => income - expense;

  /// Taux d'épargne = (revenus − dépenses) / revenus (0 si pas de revenus).
  double get savingsRate => income > 0 ? (income - expense) / income : 0;

  String get label =>
      DateFormat('MMM', 'fr_FR').format(DateTime(year, month)).replaceAll('.', '');

  bool sameMonth(DateTime d) => d.year == year && d.month == month;
}

/// Une transaction minimale pour l'agrégation.
typedef TxRow = ({DateTime date, double amount, bool isIncome});

/// Agrège les transactions par mois sur les [months] derniers mois calendaires
/// (mois courant inclus), en remplissant les mois sans opération à zéro.
List<MonthStat> monthlyStatsFrom(
  Iterable<TxRow> txs, {
  required DateTime now,
  int months = 6,
}) {
  // Prépare la liste ordonnée des mois (du plus ancien au plus récent).
  final result = <MonthStat>[];
  final buckets = <String, List<double>>{}; // 'y-m' -> [income, expense]

  String key(int y, int m) => '$y-$m';

  for (var i = months - 1; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    buckets[key(d.year, d.month)] = [0, 0];
  }

  for (final t in txs) {
    final k = key(t.date.year, t.date.month);
    final b = buckets[k];
    if (b == null) continue;
    if (t.isIncome) {
      b[0] += t.amount;
    } else {
      b[1] += t.amount;
    }
  }

  for (var i = months - 1; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final b = buckets[key(d.year, d.month)]!;
    result.add(MonthStat(
      year: d.year,
      month: d.month,
      income: b[0],
      expense: b[1],
    ));
  }
  return result;
}

/// Variation relative entre deux valeurs (pour les deltas KPI). null si base 0.
double? relativeDelta(double current, double previous) {
  if (previous == 0) return null;
  return (current - previous) / previous.abs();
}
