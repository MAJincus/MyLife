import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/features/insights/correlations.dart';

void main() {
  test('pearson : corrélation positive parfaite', () {
    final r = pearson([1, 2, 3, 4], [2, 4, 6, 8]);
    expect(r, closeTo(1.0, 1e-9));
  });

  test('pearson : corrélation négative parfaite', () {
    final r = pearson([1, 2, 3, 4], [8, 6, 4, 2]);
    expect(r, closeTo(-1.0, 1e-9));
  });

  test('pearson : série constante → null', () {
    expect(pearson([1, 1, 1, 1], [1, 2, 3, 4]), isNull);
  });

  DateTime d(int day) => DateTime(2026, 8, day);

  test('détecte un lien sommeil↔douleur sur jours communs', () {
    // Moins de sommeil → plus de douleur (corrélation négative forte).
    final series = <String, Map<DateTime, double>>{
      'Sommeil (h)': {
        for (var i = 1; i <= 8; i++) d(i): 9.0 - i, // 8,7,6,5,4,3,2,1
      },
      'Douleur (0-10)': {
        for (var i = 1; i <= 8; i++) d(i): i.toDouble(), // 1..8
      },
    };
    final cors = computeCorrelations(series, minSamples: 6);
    expect(cors, isNotEmpty);
    expect(cors.first.isPositive, isFalse);
    expect(cors.first.strength, greaterThan(0.9));
    expect(cors.first.samples, 8);
  });

  test('ignore les paires avec trop peu de jours communs', () {
    final series = <String, Map<DateTime, double>>{
      'A': {d(1): 1, d(2): 2, d(3): 3},
      'B': {d(1): 3, d(2): 2, d(3): 1},
    };
    expect(computeCorrelations(series, minSamples: 6), isEmpty);
  });
}
