/// Transaction simplifiée (montant signé : revenu > 0, dépense < 0).
class TxLite {
  TxLite({required this.date, required this.amount, required this.label});
  final DateTime date;
  final double amount;
  final String label;
}

/// Une opération récurrente détectée.
class Recurring {
  Recurring({
    required this.label,
    required this.typicalAmount,
    required this.frequency,
    required this.occurrences,
    required this.lastDate,
  });
  final String label;
  final double typicalAmount; // signé
  final String frequency; // 'monthly' | 'weekly' | 'irregular'
  final int occurrences;
  final DateTime lastDate;

  bool get isIncome => typicalAmount > 0;
  double get monthlyEquivalent =>
      frequency == 'weekly' ? typicalAmount * 4.33 : typicalAmount;
}

/// Nettoie un libellé bancaire pour regrouper les opérations d'un même
/// émetteur : suppression des chiffres (dates, n° de carte), de la ponctuation
/// et des mots parasites (CB, VIREMENT, PRLV…).
String normalizeLabel(String raw) {
  var t = raw.toUpperCase();
  t = t.replaceAll(RegExp(r'[0-9]+'), ' ');
  t = t.replaceAll(RegExp(r'[^A-ZÀ-Ÿ ]'), ' ');

  const noise = {
    'CB', 'CARTE', 'PAIEMENT', 'PAIMENT', 'VIR', 'VIREMENT', 'VIRT',
    'PRLV', 'PRELEVEMENT', 'PRELVT', 'SEPA', 'ACHAT', 'FACTURE', 'FACT',
    'DU', 'LE', 'REF', 'MANDAT', 'DE', 'DDE', 'DEB', 'DIFFERE', 'RETRAIT',
    'ECH', 'ECHEANCE', 'AVEC', 'POUR', 'PAR', 'MENSUALITE', 'ABONNEMENT',
  };

  final tokens = t
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1 && !noise.contains(w))
      .toList();
  return tokens.take(4).join(' ').trim();
}

double _median(List<double> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// Détecte les opérations récurrentes : même émetteur revenant sur plusieurs
/// mois, montant du même signe. [minOccurrences] = nb minimum d'apparitions.
List<Recurring> detectRecurring(List<TxLite> txs, {int minOccurrences = 3}) {
  final groups = <String, List<TxLite>>{};
  for (final t in txs) {
    final key = normalizeLabel(t.label);
    if (key.isEmpty) continue;
    groups.putIfAbsent(key, () => []).add(t);
  }

  final result = <Recurring>[];
  groups.forEach((key, items) {
    if (items.length < minOccurrences) return;

    // Même signe pour tous (sinon ce n'est pas une charge/revenu stable).
    final positive = items.where((t) => t.amount > 0).length;
    final negative = items.length - positive;
    if (positive != 0 && negative != 0) return;

    // Doit apparaître sur au moins 2 mois distincts.
    final months = items.map((t) => '${t.date.year}-${t.date.month}').toSet();
    if (months.length < 2) return;

    final amounts = items.map((t) => t.amount).toList();
    final typical = _median(amounts);

    // Fréquence via l'écart moyen entre occurrences.
    final dates = items.map((t) => t.date).toList()..sort();
    var gapSum = 0;
    for (var i = 1; i < dates.length; i++) {
      gapSum += dates[i].difference(dates[i - 1]).inDays;
    }
    final avgGap = gapSum / (dates.length - 1);
    final frequency = avgGap <= 10
        ? 'weekly'
        : avgGap <= 45
            ? 'monthly'
            : 'irregular';

    result.add(Recurring(
      label: key,
      typicalAmount: typical,
      frequency: frequency,
      occurrences: items.length,
      lastDate: dates.last,
    ));
  });

  // Charges (montant négatif) triées par montant décroissant, puis revenus.
  result.sort((a, b) => a.monthlyEquivalent.compareTo(b.monthlyEquivalent));
  return result;
}

/// Synthèse mensuelle des récurrences.
class RecurringSummary {
  RecurringSummary(this.items);
  final List<Recurring> items;

  double get monthlyIncome => items
      .where((r) => r.isIncome)
      .fold(0, (s, r) => s + r.monthlyEquivalent);
  double get monthlyCharges => items
      .where((r) => !r.isIncome)
      .fold(0, (s, r) => s + r.monthlyEquivalent.abs());

  /// Reste à vivre = revenus récurrents − charges récurrentes.
  double get leftToLive => monthlyIncome - monthlyCharges;

  List<Recurring> get charges => items.where((r) => !r.isIncome).toList();
  List<Recurring> get incomes => items.where((r) => r.isIncome).toList();
}
