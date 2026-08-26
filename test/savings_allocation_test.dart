import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/features/finance/savings_allocation.dart';

void main() {
  test('répartition égale sans objectif', () {
    final r = allocateSavings(300, [
      Pocket(id: 1, name: 'A', weight: 1),
      Pocket(id: 2, name: 'B', weight: 1),
      Pocket(id: 3, name: 'C', weight: 1),
    ]);
    expect(r[1], 100);
    expect(r[2], 100);
    expect(r[3], 100);
  });

  test('répartition pondérée', () {
    final r = allocateSavings(600, [
      Pocket(id: 1, name: 'Important', weight: 5),
      Pocket(id: 2, name: 'Moyen', weight: 1),
    ]);
    expect(r[1], 500);
    expect(r[2], 100);
  });

  test('plafonne à l\'objectif et redistribue le surplus', () {
    // Poche 1 poids 1 mais ne peut recevoir que 50 → le reste va à la poche 2.
    final r = allocateSavings(300, [
      Pocket(id: 1, name: 'Presque plein', weight: 1, remaining: 50),
      Pocket(id: 2, name: 'Ouverte', weight: 1),
    ]);
    expect(r[1], 50);
    expect(r[2], 250);
  });

  test('objectif déjà atteint → 0, redistribué', () {
    final r = allocateSavings(200, [
      Pocket(id: 1, name: 'Atteint', weight: 3, remaining: 0),
      Pocket(id: 2, name: 'Ouverte', weight: 1),
    ]);
    expect(r[1], 0);
    expect(r[2], 200);
  });

  test('capacité nulle → tout à zéro', () {
    final r = allocateSavings(0, [
      Pocket(id: 1, name: 'A', weight: 3),
    ]);
    expect(r[1], 0);
  });

  test('la somme allouée ne dépasse pas la capacité', () {
    final r = allocateSavings(1000, [
      Pocket(id: 1, name: 'A', weight: 2, remaining: 100),
      Pocket(id: 2, name: 'B', weight: 3, remaining: 200),
      Pocket(id: 3, name: 'C', weight: 1),
    ]);
    final total = r.values.fold<double>(0, (s, v) => s + v);
    expect(total, closeTo(1000, 0.01));
    expect(r[1], 100);
    expect(r[2], 200);
    expect(r[3], 700);
  });
}
