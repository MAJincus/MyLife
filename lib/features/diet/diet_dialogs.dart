import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import 'barcode_scan.dart';
import 'diet_repository.dart';
import 'hydration_reminders.dart';

Future<void> _sheet(BuildContext context, Widget child) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: child,
    ),
  );
}

String _defaultMealType() {
  final h = DateTime.now().hour;
  if (h < 11) return 'breakfast';
  if (h < 15) return 'lunch';
  if (h < 18) return 'snack';
  return 'dinner';
}

// ---------------------- REPAS ----------------------

Future<void> showAddMealSheet(BuildContext context, WidgetRef ref) =>
    _sheet(context, _AddMealForm(ref: ref));

class _AddMealForm extends StatefulWidget {
  const _AddMealForm({required this.ref});
  final WidgetRef ref;
  @override
  State<_AddMealForm> createState() => _AddMealFormState();
}

class _AddMealFormState extends State<_AddMealForm> {
  String _mealType = _defaultMealType();
  final _label = TextEditingController();
  final _qty = TextEditingController(text: '100');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  Food? _selectedFood;
  bool _saveToLibrary = false;
  bool _scanning = false;

  // Valeurs pour 100 g de la source active (aliment sélectionné ou scan).
  double? _srcKcal, _srcProt, _srcCarb, _srcFat;
  bool get _hasSource => _srcKcal != null;

  @override
  void dispose() {
    for (final c in [_label, _qty, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setSource(double kcal, double prot, double carb, double fat) {
    _srcKcal = kcal;
    _srcProt = prot;
    _srcCarb = carb;
    _srcFat = fat;
    _recompute();
  }

  void _applyFood(Food? food) {
    _selectedFood = food;
    if (food != null) {
      _label.text = food.name;
      _setSource(food.kcalPer100, food.proteinPer100, food.carbsPer100,
          food.fatPer100);
    } else {
      _srcKcal = _srcProt = _srcCarb = _srcFat = null;
    }
    setState(() {});
  }

  void _recompute() {
    if (!_hasSource) return;
    final grams = double.tryParse(_qty.text.replaceAll(',', '.')) ?? 0;
    final f = grams / 100.0;
    _kcal.text = (_srcKcal! * f).round().toString();
    _protein.text = (_srcProt! * f).round().toString();
    _carbs.text = (_srcCarb! * f).round().toString();
    _fat.text = (_srcFat! * f).round().toString();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    setState(() => _scanning = true);
    final product = await lookupOpenFoodFacts(code);
    if (!mounted) return;
    setState(() => _scanning = false);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit introuvable sur OpenFoodFacts')),
      );
      return;
    }
    setState(() {
      _selectedFood = null;
      _label.text = product.name;
      if ((double.tryParse(_qty.text) ?? 0) == 0) _qty.text = '100';
      _setSource(product.kcalPer100, product.proteinPer100,
          product.carbsPer100, product.fatPer100);
    });
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _submit() async {
    final kcal = _num(_kcal);
    if (_label.text.trim().isEmpty || kcal <= 0) return;
    final repo = widget.ref.read(dietRepositoryProvider);
    final grams = _num(_qty);

    int? foodId = _selectedFood?.id;
    if (_saveToLibrary && _selectedFood == null && grams > 0) {
      foodId = await repo.addFood(FoodsCompanion.insert(
        name: _label.text.trim(),
        kcalPer100: kcal / grams * 100,
        proteinPer100: Value(_num(_protein) / grams * 100),
        carbsPer100: Value(_num(_carbs) / grams * 100),
        fatPer100: Value(_num(_fat) / grams * 100),
      ));
    }

    await repo.addMeal(
      at: DateTime.now(),
      mealType: _mealType,
      label: _label.text.trim(),
      quantityGrams: grams,
      kcal: kcal,
      protein: _num(_protein),
      carbs: _num(_carbs),
      fat: _num(_fat),
      foodId: foodId,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.ref.read(dietRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ajouter un repas',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                _scanning
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scanner'),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'breakfast', label: Text('Matin')),
                ButtonSegment(value: 'lunch', label: Text('Midi')),
                ButtonSegment(value: 'snack', label: Text('Collation')),
                ButtonSegment(value: 'dinner', label: Text('Soir')),
              ],
              selected: {_mealType},
              onSelectionChanged: (s) => setState(() => _mealType = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Food>>(
              stream: repo.watchFoods(),
              builder: (context, snap) {
                final foods = snap.data ?? const <Food>[];
                if (foods.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<Food>(
                  initialValue: _selectedFood,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Depuis mes aliments (optionnel)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  items: [
                    const DropdownMenuItem<Food>(
                        value: null, child: Text('Saisie libre')),
                    for (final f in foods)
                      DropdownMenuItem(
                          value: f,
                          child: Text('${f.name} · ${f.kcalPer100.round()} kcal/100g',
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _applyFood,
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Aliment',
                prefixIcon: Icon(Icons.lunch_dining),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantité (g)',
                prefixIcon: Icon(Icons.scale),
              ),
              onChanged: (_) {
                if (_hasSource) setState(_recompute);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numField(_kcal, 'kcal')),
                const SizedBox(width: 8),
                Expanded(child: _numField(_protein, 'Prot. g')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _numField(_carbs, 'Gluc. g')),
                const SizedBox(width: 8),
                Expanded(child: _numField(_fat, 'Lip. g')),
              ],
            ),
            if (_selectedFood == null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _saveToLibrary,
                onChanged: (v) => setState(() => _saveToLibrary = v ?? false),
                title: const Text('Enregistrer dans mes aliments'),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _submit, child: const Text('Ajouter')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      );
}

// ---------------------- POIDS ----------------------

Future<void> showAddWeightSheet(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mon poids'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Poids (kg)',
          prefixIcon: Icon(Icons.monitor_weight),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () async {
            final v = double.tryParse(controller.text.replaceAll(',', '.'));
            if (v != null && v > 0) {
              await ref.read(dietRepositoryProvider).addWeight(v);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

// ---------------------- ACTIVITÉ ----------------------

Future<void> showAddActivitySheet(BuildContext context, WidgetRef ref) =>
    _sheet(context, _AddActivityForm(ref: ref));

class _AddActivityForm extends StatefulWidget {
  const _AddActivityForm({required this.ref});
  final WidgetRef ref;
  @override
  State<_AddActivityForm> createState() => _AddActivityFormState();
}

class _AddActivityFormState extends State<_AddActivityForm> {
  // kcal/min approximatifs pour ~70 kg.
  static const _types = {
    'Marche': 4.0,
    'Course': 11.0,
    'Vélo': 8.0,
    'Musculation': 6.0,
    'Natation': 9.0,
    'Autre': 6.0,
  };
  String _type = 'Marche';
  final _duration = TextEditingController(text: '30');
  final _kcal = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _duration.dispose();
    _kcal.dispose();
    super.dispose();
  }

  void _recompute() {
    final min = int.tryParse(_duration.text) ?? 0;
    _kcal.text = (_types[_type]! * min).round().toString();
  }

  Future<void> _submit() async {
    final min = int.tryParse(_duration.text) ?? 0;
    final kcal = double.tryParse(_kcal.text) ?? 0;
    if (min <= 0) return;
    await widget.ref.read(dietRepositoryProvider).addActivity(
          type: _type,
          durationMinutes: min,
          kcalBurned: kcal,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activité physique',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final t in _types.keys)
                ChoiceChip(
                  label: Text(t),
                  selected: _type == t,
                  onSelected: (_) => setState(() {
                    _type = t;
                    _recompute();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Durée (min)',
              prefixIcon: Icon(Icons.timer),
            ),
            onChanged: (_) => setState(_recompute),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kcal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Calories brûlées (estimé)',
              prefixIcon: Icon(Icons.local_fire_department),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _submit, child: const Text('Enregistrer')),
          ),
        ],
      ),
    );
  }
}

// ---------------------- PROFIL / OBJECTIF ----------------------

Future<void> showProfileSheet(BuildContext context, ProviderContainer container) {
  return _sheet(context, _ProfileForm(container: container));
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.container});
  final ProviderContainer container;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _height = TextEditingController();
  final _birthYear = TextEditingController();
  final _target = TextEditingController();
  final _targetWeight = TextEditingController();
  String _sex = 'other';
  String _goal = 'maintain';
  double _proteinPerKg = kDefaultProteinPerKg;
  double _fatPerKg = kDefaultFatPerKg;
  bool _hydrationOn = false;
  int _hydrationInterval = 2;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.container.read(dietRepositoryProvider);
    final p = await repo.watchProfile().first;
    final hyOn = await HydrationReminders.isEnabled();
    final hyInt = await HydrationReminders.intervalHours();
    setState(() {
      _sex = p.sex;
      _goal = p.dietGoal;
      _proteinPerKg = p.proteinPerKg ?? kDefaultProteinPerKg;
      _fatPerKg = p.fatPerKg ?? kDefaultFatPerKg;
      _hydrationOn = hyOn;
      _hydrationInterval = hyInt;
      if (p.heightCm != null) _height.text = '${p.heightCm}';
      if (p.birthYear != null) _birthYear.text = '${p.birthYear}';
      if (p.dailyKcalTarget != null) _target.text = '${p.dailyKcalTarget}';
      if (p.targetWeightKg != null) {
        _targetWeight.text = p.targetWeightKg!.toStringAsFixed(1);
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _height.dispose();
    _birthYear.dispose();
    _target.dispose();
    _targetWeight.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = widget.container.read(dietRepositoryProvider);
    await repo.updateProfile(ProfileCompanion(
      sex: Value(_sex),
      dietGoal: Value(_goal),
      heightCm: Value(int.tryParse(_height.text)),
      birthYear: Value(int.tryParse(_birthYear.text)),
      dailyKcalTarget: Value(int.tryParse(_target.text)),
      targetWeightKg:
          Value(double.tryParse(_targetWeight.text.replaceAll(',', '.'))),
      proteinPerKg: Value(_proteinPerKg),
      fatPerKg: Value(_fatPerKg),
    ));
    await HydrationReminders.configure(
        enabled: _hydrationOn, interval: _hydrationInterval);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mon objectif',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Sert à estimer ton besoin calorique et adapter les menus.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Femme')),
                ButtonSegment(value: 'male', label: Text('Homme')),
                ButtonSegment(value: 'other', label: Text('Autre')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Taille (cm)',
                        prefixIcon: Icon(Icons.height)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _birthYear,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Année naissance'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Objectif', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lose', label: Text('Perdre')),
                ButtonSegment(value: 'maintain', label: Text('Maintenir')),
                ButtonSegment(value: 'gain', label: Text('Prendre')),
              ],
              selected: {_goal},
              onSelectionChanged: (s) => setState(() => _goal = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Objectif kcal (auto si vide)',
                      prefixIcon: Icon(Icons.local_fire_department),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _targetWeight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Poids cible (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---- Objectifs macros ----
            Text('Objectifs macros',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final p in const [
                  ('Équilibré', 1.8, 0.9),
                  ('Muscle', 2.2, 0.9),
                  ('Sèche', 2.4, 0.8),
                  ('Endurance', 1.6, 1.0),
                ])
                  ChoiceChip(
                    label: Text(p.$1),
                    selected: _proteinPerKg == p.$2 && _fatPerKg == p.$3,
                    onSelected: (_) => setState(() {
                      _proteinPerKg = p.$2;
                      _fatPerKg = p.$3;
                    }),
                  ),
              ],
            ),
            Text('Protéines : ${_proteinPerKg.toStringAsFixed(1)} g/kg'),
            Slider(
              value: _proteinPerKg,
              min: 1.2,
              max: 2.6,
              divisions: 14,
              label: _proteinPerKg.toStringAsFixed(1),
              onChanged: (v) =>
                  setState(() => _proteinPerKg = (v * 10).round() / 10),
            ),
            Text('Lipides : ${_fatPerKg.toStringAsFixed(1)} g/kg'),
            Slider(
              value: _fatPerKg,
              min: 0.6,
              max: 1.2,
              divisions: 6,
              label: _fatPerKg.toStringAsFixed(1),
              onChanged: (v) =>
                  setState(() => _fatPerKg = (v * 10).round() / 10),
            ),
            Text('Les glucides s\'ajustent automatiquement au reste.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 16),

            // ---- Rappels d'hydratation ----
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.water_drop, color: Color(0xFF2E9BD6)),
              title: const Text('Rappels d\'hydratation'),
              subtitle: const Text('Notifications entre 8 h et 21 h'),
              value: _hydrationOn,
              onChanged: (v) => setState(() => _hydrationOn = v),
            ),
            if (_hydrationOn)
              Row(
                children: [
                  const Text('Toutes les '),
                  const SizedBox(width: 8),
                  for (final h in const [1, 2, 3])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$h h'),
                        selected: _hydrationInterval == h,
                        onSelected: (_) =>
                            setState(() => _hydrationInterval = h),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _submit, child: const Text('Enregistrer')),
            ),
          ],
        ),
      ),
    );
  }
}
