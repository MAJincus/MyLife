import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/features/diet/diet_repository.dart';

void main() {
  test('objectifs macros depuis le poids et les calories', () {
    // 80 kg, 2000 kcal : P=1.8*80=144g, L=0.9*80=72g,
    // glucides = (2000 - 144*4 - 72*9)/4 = (2000-576-648)/4 = 776/4 = 194g
    final m = macroTargets(2000, 80);
    expect(m.protein, closeTo(144, 0.01));
    expect(m.fat, closeTo(72, 0.01));
    expect(m.carbs, closeTo(194, 0.01));
  });

  test('glucides jamais négatifs si calories trop basses', () {
    final m = macroTargets(500, 90); // prot+lip dépassent déjà 500 kcal
    expect(m.carbs, 0);
  });

  test('cible hydratation ~35 ml/kg, min 1500, arrondie à la centaine', () {
    expect(hydrationTargetMl(70), 2500); // 70*35=2450 -> 2500
    expect(hydrationTargetMl(80), 2800); // 2800
    expect(hydrationTargetMl(30), 1500); // min
  });
}
