import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database.dart';
import '../assistant/assistant_button.dart';
import 'diet_dialogs.dart';
import 'diet_icons.dart';
import 'diet_menus.dart';
import 'diet_repository.dart';

class DietScreen extends StatelessWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diète'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Journal'),
              Tab(text: 'Poids'),
              Tab(text: 'Menus'),
            ],
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Objectif',
                onPressed: () => showProfileSheet(
                    context, ProviderScope.containerOf(context)),
              ),
            ),
            const AssistantButton(),
          ],
        ),
        body: const TabBarView(
          children: [
            _JournalTab(),
            _WeightTab(),
            _MenusTab(),
          ],
        ),
      ),
    );
  }
}

// ============================ JOURNAL ============================

class _JournalTab extends ConsumerWidget {
  const _JournalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dietRepositoryProvider);
    final today = DateTime.now();

    return Scaffold(
      body: StreamBuilder<ProfileData>(
        stream: repo.watchProfile(),
        builder: (context, profileSnap) {
          final profile = profileSnap.data;
          return StreamBuilder<List<WeightEntry>>(
            stream: repo.watchWeights(limit: 1),
            builder: (context, wSnap) {
              final latestWeight =
                  (wSnap.data?.isNotEmpty ?? false) ? wSnap.data!.first.weightKg : null;
              final target = _resolveTarget(profile, latestWeight);

              return StreamBuilder<DayNutrition>(
                stream: repo.watchDayNutrition(today),
                builder: (context, nutSnap) {
                  final nut = nutSnap.data ?? DayNutrition();
                  return StreamBuilder<List<ActivityEntry>>(
                    stream: repo.watchActivitiesForDay(today),
                    builder: (context, actSnap) {
                      final activities = actSnap.data ?? const [];
                      final burned = activities.fold<double>(
                          0, (s, a) => s + a.kcalBurned);
                      return _JournalBody(
                        target: target,
                        nutrition: nut,
                        burned: burned,
                        activities: activities,
                        hasProfile: target != null,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddMealSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Repas'),
      ),
    );
  }

  static int? _resolveTarget(ProfileData? p, double? weight) {
    if (p == null) return null;
    if (p.dailyKcalTarget != null) return p.dailyKcalTarget;
    if (p.heightCm != null && p.birthYear != null && weight != null) {
      return Calories.dailyTarget(
        sex: p.sex,
        age: DateTime.now().year - p.birthYear!,
        heightCm: p.heightCm!,
        weightKg: weight,
        goal: p.dietGoal,
      );
    }
    return null;
  }
}

class _JournalBody extends ConsumerWidget {
  const _JournalBody({
    required this.target,
    required this.nutrition,
    required this.burned,
    required this.activities,
    required this.hasProfile,
  });
  final int? target;
  final DayNutrition nutrition;
  final double burned;
  final List<ActivityEntry> activities;
  final bool hasProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dietRepositoryProvider);
    final today = DateTime.now();
    final budget = target != null ? target! + burned.round() : null;
    final remaining = budget != null ? budget - nutrition.kcal.round() : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _CalorieRing(
                  consumed: nutrition.kcal.round(),
                  budget: budget,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (remaining != null) ...[
                        Text(
                          remaining >= 0
                              ? '$remaining kcal restantes'
                              : '${-remaining} kcal au-dessus',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('${nutrition.kcal.round()} / $budget kcal',
                            style: Theme.of(context).textTheme.bodySmall),
                        if (burned > 0)
                          Text('dont +${burned.round()} kcal d\'activité',
                              style: Theme.of(context).textTheme.bodySmall),
                      ] else
                        TextButton.icon(
                          onPressed: () => showProfileSheet(
                              context, ProviderScope.containerOf(context)),
                          icon: const Icon(Icons.flag),
                          label: const Text('Définir mon objectif'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MacroBar(nutrition: nutrition),
        const SizedBox(height: 12),

        // Activité du jour
        SectionHeader(
          icon: Icons.directions_run,
          title: 'Activité',
          color: const Color(0xFF3B82F6),
          trailing: TextButton.icon(
            onPressed: () => showAddActivitySheet(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter'),
          ),
        ),
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text('Aucune activité aujourd\'hui.',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.outline)),
          )
        else
          for (final a in activities)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 8),
              dense: true,
              leading: Icon(activityIcon(a.type),
                  size: 20, color: const Color(0xFF3B82F6)),
              title: Text(a.type.isEmpty ? 'Activité' : a.type),
              subtitle: Text('${a.durationMinutes} min'),
              trailing: Text('${a.kcalBurned.round()} kcal',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onLongPress: () => repo.deleteActivity(a.id),
            ),
        const SizedBox(height: 12),

        const SectionHeader(
            icon: Icons.restaurant_menu,
            title: 'Repas',
            color: ModuleColorsDiet.color),
        const SizedBox(height: 4),
        StreamBuilder<List<MealEntry>>(
          stream: repo.watchMealsForDay(today),
          builder: (context, snap) {
            final meals = snap.data ?? const [];
            if (meals.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Ajoute ton premier repas avec « + ».',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline)),
              );
            }
            return Column(
              children: [
                for (final type in _mealOrder)
                  ..._buildMealGroup(context, repo, type,
                      meals.where((m) => m.mealType == type).toList()),
              ],
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

  List<Widget> _buildMealGroup(BuildContext context, DietRepository repo,
      String type, List<MealEntry> meals) {
    if (meals.isEmpty) return [];
    final total = meals.fold<double>(0, (s, m) => s + m.kcal);
    final color = mealTypeColor(type);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(mealTypeIcon(type), size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Text(mealTypeLabel(type),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${total.round()} kcal',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      for (final m in meals)
        Dismissible(
          key: ValueKey('meal_${m.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) => repo.deleteMeal(m.id),
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 8),
            dense: true,
            leading: Icon(Icons.restaurant, size: 18, color: color),
            title: Text(m.label.isEmpty ? 'Aliment' : m.label),
            subtitle: m.quantityGrams > 0
                ? Text('${m.quantityGrams.round()} g')
                : null,
            trailing: Text('${m.kcal.round()} kcal',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
    ];
  }
}

class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.consumed, this.budget});
  final int consumed;
  final int? budget;

  @override
  Widget build(BuildContext context) {
    final ratio =
        budget != null && budget! > 0 ? (consumed / budget!).clamp(0.0, 1.0) : 0.0;
    final over = budget != null && consumed > budget!;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: budget == null ? null : ratio.toDouble(),
              strokeWidth: 9,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: over ? Colors.red : ModuleColorsDiet.color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$consumed',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Text('kcal', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({required this.nutrition});
  final DayNutrition nutrition;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _macro('Protéines', nutrition.protein, Colors.redAccent,
                Icons.egg_alt),
            _macro('Glucides', nutrition.carbs, Colors.orangeAccent,
                Icons.bakery_dining),
            _macro('Lipides', nutrition.fat, Colors.blueAccent,
                Icons.water_drop),
          ],
        ),
      ),
    );
  }

  Widget _macro(String label, double grams, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text('${grams.round()} g',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ============================ POIDS ============================

class _WeightTab extends ConsumerWidget {
  const _WeightTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dietRepositoryProvider);
    return Scaffold(
      body: StreamBuilder<List<WeightEntry>>(
        stream: repo.watchWeights(),
        builder: (context, snap) {
          final entries = snap.data ?? const [];
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Enregistre ton poids pour suivre ta courbe.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final latest = entries.first.weightKg;
          final oldest = entries.last.weightKg;
          final delta = latest - oldest;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.monitor_weight, color: Colors.teal),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${latest.toStringAsFixed(1)} kg',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg sur la période',
                            style: TextStyle(
                                color: delta > 0 ? Colors.red : Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _WeightChart(
                  entries: entries.reversed.toList()),
              const SizedBox(height: 12),
              for (final e in entries)
                Dismissible(
                  key: ValueKey('weight_${e.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => repo.deleteWeight(e.id),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.circle, size: 10, color: Colors.teal),
                    title: Text('${e.weightKg.toStringAsFixed(1)} kg'),
                    trailing: Text(Fmt.dayMonth(e.date)),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddWeightSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Poids'),
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries});
  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) return const SizedBox.shrink();
    final values = entries.map((e) => e.weightKg).toList();
    final minV = values.reduce(math.min) - 1;
    final maxV = values.reduce(math.max) + 1;
    final spots = [
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].weightKg),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: minV,
              maxY: maxV,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.teal,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.teal.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================ MENUS ============================

class _MenusTab extends ConsumerWidget {
  const _MenusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dietRepositoryProvider);
    return StreamBuilder<ProfileData>(
      stream: repo.watchProfile(),
      builder: (context, snap) {
        final target = snap.data?.dailyKcalTarget ?? 2000;
        final menus = suggestMenus(target);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Suggestions autour de $target kcal/jour',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Idées équilibrées, ajustées à ton objectif. Touche un repas '
              'pour l\'ajouter à ton journal.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            for (final menu in menus) _MenuCard(menu: menu),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.menu});
  final SuggestedMenu menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dietRepositoryProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(menu.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('${menu.totalKcal} kcal',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ModuleColorsDiet.color)),
              ],
            ),
            const Divider(),
            for (final item in menu.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(mealTypeIcon(item.mealType),
                    color: mealTypeColor(item.mealType), size: 22),
                title: Text(item.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${item.kcal} kcal'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Ajouter au journal',
                      onPressed: () async {
                        await repo.addMeal(
                          at: DateTime.now(),
                          mealType: item.mealType,
                          label: item.label,
                          quantityGrams: 0,
                          kcal: item.kcal.toDouble(),
                          protein: item.protein.toDouble(),
                          carbs: item.carbs.toDouble(),
                          fat: item.fat.toDouble(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('${item.label} ajouté au journal'),
                                duration: const Duration(seconds: 1)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ModuleColorsDiet {
  static const color = Color(0xFFEF6C00);
}
