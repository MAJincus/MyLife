/// Libellé lisible d'un type de repas.
String mealTypeLabel(String type) => switch (type) {
      'breakfast' => 'Petit-déj',
      'lunch' => 'Déjeuner',
      'dinner' => 'Dîner',
      _ => 'Collation',
    };

class MenuItem {
  const MenuItem({
    required this.mealType,
    required this.label,
    required this.kcal,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });
  final String mealType;
  final String label;
  final int kcal;
  final int protein;
  final int carbs;
  final int fat;
}

class SuggestedMenu {
  const SuggestedMenu({required this.title, required this.items});
  final String title;
  final List<MenuItem> items;
  int get totalKcal => items.fold(0, (s, i) => s + i.kcal);
}

/// Trois menus-types, mis à l'échelle du besoin calorique de l'utilisateur.
/// Les menus de base sont calibrés pour ~2000 kcal puis multipliés.
List<SuggestedMenu> suggestMenus(int targetKcal) {
  final factor = targetKcal / 2000.0;

  MenuItem scale(MenuItem m) => MenuItem(
        mealType: m.mealType,
        label: m.label,
        kcal: (m.kcal * factor).round(),
        protein: (m.protein * factor).round(),
        carbs: (m.carbs * factor).round(),
        fat: (m.fat * factor).round(),
      );

  final base = <SuggestedMenu>[
    const SuggestedMenu(
      title: 'Équilibré méditerranéen',
      items: [
        MenuItem(
            mealType: 'breakfast',
            label: 'Flocons d\'avoine, yaourt grec, fruits rouges',
            kcal: 420,
            protein: 22,
            carbs: 55,
            fat: 12),
        MenuItem(
            mealType: 'lunch',
            label: 'Poulet grillé, quinoa, légumes rôtis, huile d\'olive',
            kcal: 650,
            protein: 45,
            carbs: 60,
            fat: 22),
        MenuItem(
            mealType: 'snack',
            label: 'Poignée d\'amandes + pomme',
            kcal: 230,
            protein: 6,
            carbs: 25,
            fat: 13),
        MenuItem(
            mealType: 'dinner',
            label: 'Saumon, patate douce, brocolis',
            kcal: 700,
            protein: 40,
            carbs: 55,
            fat: 30),
      ],
    ),
    const SuggestedMenu(
      title: 'Riche en protéines',
      items: [
        MenuItem(
            mealType: 'breakfast',
            label: 'Œufs brouillés, pain complet, avocat',
            kcal: 450,
            protein: 26,
            carbs: 32,
            fat: 24),
        MenuItem(
            mealType: 'lunch',
            label: 'Bœuf maigre, riz basmati, haricots verts',
            kcal: 680,
            protein: 50,
            carbs: 62,
            fat: 20),
        MenuItem(
            mealType: 'snack',
            label: 'Fromage blanc 0% + noix',
            kcal: 220,
            protein: 20,
            carbs: 10,
            fat: 11),
        MenuItem(
            mealType: 'dinner',
            label: 'Cabillaud, lentilles, salade',
            kcal: 650,
            protein: 48,
            carbs: 55,
            fat: 18),
      ],
    ),
    const SuggestedMenu(
      title: 'Végétarien gourmand',
      items: [
        MenuItem(
            mealType: 'breakfast',
            label: 'Smoothie banane-épinards, granola',
            kcal: 400,
            protein: 14,
            carbs: 62,
            fat: 12),
        MenuItem(
            mealType: 'lunch',
            label: 'Buddha bowl pois chiches, avocat, tahini',
            kcal: 680,
            protein: 24,
            carbs: 72,
            fat: 30),
        MenuItem(
            mealType: 'snack',
            label: 'Houmous + bâtonnets de légumes',
            kcal: 200,
            protein: 8,
            carbs: 22,
            fat: 9),
        MenuItem(
            mealType: 'dinner',
            label: 'Curry de tofu, riz complet',
            kcal: 720,
            protein: 28,
            carbs: 80,
            fat: 28),
      ],
    ),
  ];

  return [
    for (final m in base)
      SuggestedMenu(title: m.title, items: m.items.map(scale).toList()),
  ];
}
