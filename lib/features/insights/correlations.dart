import 'dart:math' as math;

/// Une corrélation détectée entre deux métriques journalières.
class Correlation {
  Correlation({
    required this.metricA,
    required this.metricB,
    required this.r,
    required this.samples,
  });
  final String metricA;
  final String metricB;
  final double r; // coefficient de Pearson (-1..1)
  final int samples;

  bool get isPositive => r > 0;
  double get strength => r.abs();
}

/// Coefficient de corrélation de Pearson, ou null si non calculable.
double? pearson(List<double> x, List<double> y) {
  final n = x.length;
  if (n < 3 || y.length != n) return null;
  final mx = x.reduce((a, b) => a + b) / n;
  final my = y.reduce((a, b) => a + b) / n;
  double sxy = 0, sxx = 0, syy = 0;
  for (var i = 0; i < n; i++) {
    final dx = x[i] - mx;
    final dy = y[i] - my;
    sxy += dx * dy;
    sxx += dx * dx;
    syy += dy * dy;
  }
  if (sxx == 0 || syy == 0) return null;
  return sxy / math.sqrt(sxx * syy);
}

/// Calcule les corrélations notables entre des séries journalières.
/// [series] : nom de métrique -> (jour -> valeur). Les jours sont des
/// DateTime à minuit. Ne garde que les paires avec assez de jours communs
/// et une corrélation d'amplitude ≥ [minStrength].
List<Correlation> computeCorrelations(
  Map<String, Map<DateTime, double>> series, {
  int minSamples = 6,
  double minStrength = 0.4,
}) {
  final names = series.keys.toList();
  final result = <Correlation>[];

  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      final a = series[names[i]]!;
      final b = series[names[j]]!;
      final commonDays = a.keys.where(b.containsKey).toList();
      if (commonDays.length < minSamples) continue;

      final xs = [for (final d in commonDays) a[d]!];
      final ys = [for (final d in commonDays) b[d]!];
      final r = pearson(xs, ys);
      if (r == null || r.abs() < minStrength) continue;

      result.add(Correlation(
        metricA: names[i],
        metricB: names[j],
        r: r,
        samples: commonDays.length,
      ));
    }
  }

  result.sort((x, y) => y.strength.compareTo(x.strength));
  return result;
}

/// Phrase lisible décrivant une corrélation.
String describeCorrelation(Correlation c) {
  final sens = c.isPositive ? 'augmente' : 'diminue';
  final force = c.strength >= 0.7
      ? 'forte'
      : c.strength >= 0.55
          ? 'nette'
          : 'modérée';
  return 'Quand « ${c.metricA} » augmente, « ${c.metricB} » a tendance à '
      '$sens (corrélation $force, r=${c.r.toStringAsFixed(2)}, '
      '${c.samples} jours).';
}
