import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database.dart';
import 'finance_repository.dart';
import 'finance_dialogs.dart';
import '../assistant/assistant_button.dart';
import 'ai_analysis_screen.dart';
import 'bilan_tab.dart';
import 'import/import_screen.dart';
import 'patrimoine_screen.dart';
import 'pocket_icons.dart';
import 'recurring_screen.dart';
import 'savings_plan.dart';
import 'treasury_screen.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Finances · ${Fmt.monthYear(DateTime.now())}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_balance),
              tooltip: 'Patrimoine',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PatrimoineScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.insights),
              tooltip: 'Analyse IA',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiAnalysisScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Importer un relevé',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
            ),
            const AssistantButton(),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dépenses'),
              Tab(text: 'Épargne'),
              Tab(text: 'Bilan'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ExpensesTab(),
            _SavingsTab(),
            BilanTab(),
          ],
        ),
      ),
    );
  }
}

// ============================ DÉPENSES ============================

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(financeRepositoryProvider);
    final now = DateTime.now();

    return Scaffold(
      body: StreamBuilder<MonthSummary>(
        stream: repo.watchMonthSummary(now),
        builder: (context, summarySnap) {
          final summary =
              summarySnap.data ?? MonthSummary(income: 0, expense: 0);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 16),
              const TreasuryCard(),
              const SizedBox(height: 12),
              const RecurringCard(),
              const SizedBox(height: 16),
              const SectionHeader(
                  icon: Icons.donut_small,
                  title: 'Répartition du mois',
                  color: ModuleColors.finance),
              const SizedBox(height: 8),
              StreamBuilder<List<CategorySpend>>(
                stream: repo.watchSpendByCategory(now),
                builder: (context, snap) {
                  final data = snap.data ?? const [];
                  if (data.isEmpty) {
                    return const _EmptyHint(
                        'Aucune dépense ce mois-ci. Ajoute-en une avec « + ».');
                  }
                  return _CategoryChart(data: data);
                },
              ),
              const SizedBox(height: 8),
              _OptimizationCard(),
              const SizedBox(height: 16),
              const SectionHeader(
                  icon: Icons.receipt_long,
                  title: 'Dernières transactions',
                  color: ModuleColors.finance),
              const SizedBox(height: 8),
              StreamBuilder<List<Transaction>>(
                stream: repo.watchTransactions(),
                builder: (context, snap) {
                  final txs = snap.data ?? const [];
                  if (txs.isEmpty) {
                    return const _EmptyHint('Rien pour l\'instant.');
                  }
                  return StreamBuilder<List<Category>>(
                    stream: repo.watchCategories(),
                    builder: (context, catSnap) {
                      final cats = {
                        for (final c in catSnap.data ?? const <Category>[])
                          c.id: c
                      };
                      return Column(
                        children: [
                          for (final t in txs)
                            _TransactionTile(
                              tx: t,
                              category: cats[t.categoryId],
                              onDelete: () => repo.deleteTransaction(t.id),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTransactionSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final positive = summary.balance >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Solde du mois',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              Fmt.euro(summary.balance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: positive ? Colors.green.shade600 : scheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MiniStat(
                  label: 'Revenus',
                  value: Fmt.euro(summary.income),
                  color: Colors.green.shade600,
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(width: 24),
                _MiniStat(
                  label: 'Dépenses',
                  value: Fmt.euro(summary.expense),
                  color: scheme.error,
                  icon: Icons.arrow_upward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.data});
  final List<CategorySpend> data;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (s, e) => s + e.total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: [
                    for (final e in data)
                      PieChartSectionData(
                        value: e.total,
                        color: Color(e.category.color),
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in data.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(e.category.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.category.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                            '${(e.total / total * 100).round()}%',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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

/// Suggestions d'optimisation basées sur les budgets de catégorie dépassés.
class _OptimizationCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(financeRepositoryProvider);
    final now = DateTime.now();
    return StreamBuilder<List<CategorySpend>>(
      stream: repo.watchSpendByCategory(now),
      builder: (context, snap) {
        final data = snap.data ?? const [];
        final overruns = [
          for (final e in data)
            if (e.category.monthlyBudget != null &&
                e.total > e.category.monthlyBudget!)
              e
        ];
        if (overruns.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Card(
          color: scheme.errorContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: scheme.error),
                    const SizedBox(width: 8),
                    Text('Optimisation',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                for (final e in overruns)
                  Text(
                    '• ${e.category.name} : ${Fmt.euro(e.total)} '
                    'dépensés pour un budget de '
                    '${Fmt.euro(e.category.monthlyBudget!)} '
                    '(${Fmt.euro(e.total - e.category.monthlyBudget!)} de trop).',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.category,
    required this.onDelete,
  });
  final Transaction tx;
  final Category? category;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.kind == 'income';
    final color = category != null
        ? Color(category!.color)
        : (isIncome ? Colors.green : Colors.grey);
    return Dismissible(
      key: ValueKey('tx_${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(_iconFor(category?.icon), color: color, size: 20),
        ),
        title: Text(category?.name ?? (isIncome ? 'Revenu' : 'Dépense')),
        subtitle: Text(
          tx.note.isEmpty ? Fmt.dayMonth(tx.date) : '${tx.note} · ${Fmt.dayMonth(tx.date)}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${Fmt.euro(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIncome ? Colors.green.shade600 : null,
          ),
        ),
      ),
    );
  }
}

// ============================ ÉPARGNE ============================

class _SavingsTab extends ConsumerWidget {
  const _SavingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(financeRepositoryProvider);
    return Scaffold(
      body: StreamBuilder<List<SavingsGoal>>(
        stream: repo.watchGoals(),
        builder: (context, snap) {
          final goals = snap.data ?? const [];
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings_outlined,
                        size: 56, color: Colors.teal),
                    const SizedBox(height: 16),
                    Text('Tes poches d\'épargne',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Répartis ton épargne entre plusieurs projets. Crée les '
                      '6 poches types, ou ajoute les tiennes avec « + ».',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => repo.seedDefaultPockets(),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Créer mes 6 poches types'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SavingsPlanCard(pockets: goals),
              const SizedBox(height: 16),
              for (final g in goals) _GoalCard(goal: g),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddGoalSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Poche'),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(financeRepositoryProvider);
    final hasTarget = goal.targetAmount > 0;
    final progress = hasTarget
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final remaining =
        (goal.targetAmount - goal.currentAmount).clamp(0, double.infinity);
    final color = Color(goal.color);

    String? eta;
    if (hasTarget && goal.targetDate != null && remaining > 0) {
      final months = goal.targetDate!.difference(DateTime.now()).inDays / 30.0;
      if (months > 0) {
        eta = 'Il faut ${Fmt.euro(remaining / months)}/mois pour tenir '
            'l\'échéance du ${Fmt.dayMonth(goal.targetDate!)}.';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(pocketIcon(goal.icon), color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Row(
                        children: [
                          Text('Priorité ',
                              style: Theme.of(context).textTheme.bodySmall),
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              i <= goal.weight
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 9,
                              color: color,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: color,
                  tooltip: 'Ajouter de l\'épargne',
                  onPressed: () => showContributeDialog(context, ref, goal),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'weight') _editWeight(context, repo);
                    if (v == 'archive') repo.archiveGoal(goal.id);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'weight', child: Text('Modifier la priorité')),
                    PopupMenuItem(value: 'archive', child: Text('Archiver')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasTarget) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${Fmt.euro(goal.currentAmount)} / ${Fmt.euro(goal.targetAmount)} '
                '(${(progress * 100).round()}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else
              Text(
                'Épargné : ${Fmt.euro(goal.currentAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (eta != null) ...[
              const SizedBox(height: 4),
              Text(eta,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editWeight(BuildContext context, FinanceRepository repo) async {
    var w = goal.weight;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Priorité de « ${goal.name} »'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Poids : $w / 5'),
              Slider(
                value: w.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$w',
                onChanged: (v) => setState(() => w = v.round()),
              ),
              const Text(
                'Plus le poids est élevé, plus cette poche reçoit une grande '
                'part de ton épargne mensuelle.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              repo.updateGoal(goal.id, SavingsGoalsCompanion(weight: Value(w)));
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// ============================ COMMUN ============================

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
}

IconData _iconFor(String? name) {
  switch (name) {
    case 'restaurant':
      return Icons.restaurant;
    case 'home':
      return Icons.home;
    case 'directions_car':
      return Icons.directions_car;
    case 'local_hospital':
      return Icons.local_hospital;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'subscriptions':
      return Icons.subscriptions;
    case 'payments':
      return Icons.payments;
    default:
      return Icons.category;
  }
}
