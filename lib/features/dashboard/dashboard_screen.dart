import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database.dart';
import '../agenda/agenda_dialogs.dart';
import '../agenda/agenda_repository.dart';
import '../assistant/assistant_button.dart';
import '../diet/diet_dialogs.dart';
import '../diet/diet_repository.dart';
import '../finance/finance_dialogs.dart';
import '../finance/finance_repository.dart';
import '../health/health_repository.dart';
import '../insights/correlation_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeRepositoryProvider);
    final health = ref.watch(healthRepositoryProvider);
    final diet = ref.watch(dietRepositoryProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyLife'),
        actions: [
          const AssistantButton(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/assistant'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Assistant'),
        backgroundColor: ModuleColors.assistant,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Hero : salutation + solde du mois ----
          _Hero(finance: finance, now: now),
          const SizedBox(height: 16),

          // ---- Actions rapides ----
          _QuickActions(),
          const SizedBox(height: 20),

          // ---- Tuiles KPI du jour ----
          const SectionHeader(icon: Icons.dashboard_customize, title: 'Aujourd\'hui'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              // Sommeil (dernière nuit)
              StreamBuilder<List<SleepEntry>>(
                stream: health.watchSleep(limit: 1),
                builder: (context, snap) {
                  final s = (snap.data?.isNotEmpty ?? false) ? snap.data!.first : null;
                  return _MetricTile(
                    icon: Icons.bedtime,
                    color: Colors.indigo,
                    label: 'Sommeil',
                    value: s == null ? '—' : Fmt.duration(s.durationMinutes),
                    sub: s == null ? 'aucune nuit notée' : 'dernière nuit',
                    onTap: () => context.go('/health'),
                  );
                },
              ),
              // Calories du jour
              StreamBuilder<DayNutrition>(
                stream: diet.watchDayNutrition(now),
                builder: (context, snap) {
                  final n = snap.data ?? DayNutrition();
                  return _MetricTile(
                    icon: Icons.local_fire_department,
                    color: ModuleColors.diet,
                    label: 'Calories',
                    value: '${n.kcal.round()}',
                    sub: 'kcal aujourd\'hui',
                    onTap: () => context.go('/diet'),
                  );
                },
              ),
              // Poids
              StreamBuilder<List<WeightEntry>>(
                stream: diet.watchWeights(limit: 2),
                builder: (context, snap) {
                  final list = snap.data ?? const [];
                  String value = '—', sub = 'non renseigné';
                  if (list.isNotEmpty) {
                    value = '${list.first.weightKg.toStringAsFixed(1)} kg';
                    if (list.length > 1) {
                      final d = list.first.weightKg - list[1].weightKg;
                      sub = '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} kg';
                    } else {
                      sub = 'dernier poids';
                    }
                  }
                  return _MetricTile(
                    icon: Icons.monitor_weight,
                    color: Colors.teal,
                    label: 'Poids',
                    value: value,
                    sub: sub,
                    onTap: () => context.go('/diet'),
                  );
                },
              ),
              // Cachets pris aujourd'hui
              StreamBuilder<Map<int, int>>(
                stream: health.watchTodayIntakeCounts(),
                builder: (context, snap) {
                  final total = (snap.data ?? const {})
                      .values
                      .fold<int>(0, (a, b) => a + b);
                  return _MetricTile(
                    icon: Icons.medication,
                    color: ModuleColors.health,
                    label: 'Cachets',
                    value: '$total',
                    sub: 'prise(s) aujourd\'hui',
                    onTap: () => context.go('/health'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---- À faire (rappels du jour / en retard) ----
          StreamBuilder<List<Reminder>>(
            stream: ref.watch(agendaRepositoryProvider).watchUpcoming(),
            builder: (context, snap) {
              final all = snap.data ?? const [];
              final end = DateTime(now.year, now.month, now.day)
                  .add(const Duration(days: 1));
              final todays = all.where((r) => r.dueAt.isBefore(end)).toList();
              if (todays.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                      icon: Icons.checklist,
                      title: 'À faire',
                      color: ModuleColors.agenda),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final r in todays.take(4))
                          ListTile(
                            dense: true,
                            leading: Icon(
                              r.dueAt.isBefore(now)
                                  ? Icons.error_outline
                                  : Icons.schedule,
                              color: r.dueAt.isBefore(now)
                                  ? Theme.of(context).colorScheme.error
                                  : ModuleColors.agenda,
                            ),
                            title: Text(r.title),
                            trailing: Text(Fmt.time(r.dueAt)),
                            onTap: () => context.go('/agenda'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // ---- Insights ----
          Card(
            color: ModuleColors.assistant.withValues(alpha: 0.10),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CorrelationScreen()),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.insights, color: ModuleColors.assistant),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Corrélations & insights',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.finance, required this.now});
  final FinanceRepository finance;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seed.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.go('/finance'),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.fullDate(now),
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                const Text('Bonjour 👋',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    )),
                const SizedBox(height: 20),
                StreamBuilder<MonthSummary>(
                  stream: finance.watchMonthSummary(now),
                  builder: (context, snap) {
                    final s = snap.data ?? MonthSummary(income: 0, expense: 0);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Solde du mois',
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 2),
                              Text(Fmt.euro(s.balance),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  )),
                            ],
                          ),
                        ),
                        _HeroStat(label: 'Revenus', value: Fmt.euro(s.income)),
                        const SizedBox(width: 16),
                        _HeroStat(label: 'Dépenses', value: Fmt.euro(s.expense)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QuickAction(
          icon: Icons.remove_circle_outline,
          label: 'Dépense',
          color: ModuleColors.finance,
          onTap: () => showAddTransactionSheet(context, ref),
        ),
        _QuickAction(
          icon: Icons.restaurant,
          label: 'Repas',
          color: ModuleColors.diet,
          onTap: () => showAddMealSheet(context, ref),
        ),
        _QuickAction(
          icon: Icons.monitor_weight,
          label: 'Poids',
          color: Colors.teal,
          onTap: () => showAddWeightSheet(context, ref),
        ),
        _QuickAction(
          icon: Icons.add_alert,
          label: 'Rappel',
          color: ModuleColors.agenda,
          onTap: () => showAddReminderSheet(context, ref),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(label,
                      style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}
