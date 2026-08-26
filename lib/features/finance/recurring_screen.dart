import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets/section_header.dart';
import 'finance_repository.dart';
import 'recurring.dart';

final recurringSummaryProvider = FutureProvider<RecurringSummary>((ref) {
  return ref.watch(financeRepositoryProvider).recurringSummary();
});

/// Carte compacte « reste à vivre » pour l'onglet Dépenses.
class RecurringCard extends ConsumerWidget {
  const RecurringCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringSummaryProvider);
    final summary = async.valueOrNull;
    if (summary == null || summary.items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecurringScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.autorenew, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text('Récurrents',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _mini(context, 'Revenus fixes',
                      Fmt.euro(summary.monthlyIncome), Colors.green.shade600),
                  _mini(context, 'Charges fixes',
                      Fmt.euro(summary.monthlyCharges),
                      Theme.of(context).colorScheme.error),
                  _mini(
                      context,
                      'Reste à vivre',
                      Fmt.euro(summary.leftToLive),
                      summary.leftToLive >= 0
                          ? Colors.green.shade700
                          : Theme.of(context).colorScheme.error),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

/// Écran détaillé des revenus/charges récurrents.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringSummaryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenus & charges fixes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(recurringSummaryProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (summary) {
          if (summary.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Pas encore de récurrence détectée.\n\n'
                  'Importe plusieurs mois de relevés : l\'app repère '
                  'automatiquement tes revenus et charges qui reviennent '
                  'chaque mois (salaire, loyer, abonnements, énergie…).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 16),
              if (summary.charges.isNotEmpty) ...[
                SectionHeader(
                    icon: Icons.arrow_circle_down,
                    title: 'Charges fixes (${summary.charges.length})',
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 4),
                for (final r in summary.charges) _RecurringTile(r: r),
                const SizedBox(height: 16),
              ],
              if (summary.incomes.isNotEmpty) ...[
                SectionHeader(
                    icon: Icons.arrow_circle_up,
                    title: 'Revenus fixes (${summary.incomes.length})',
                    color: Colors.green.shade600),
                const SizedBox(height: 4),
                for (final r in summary.incomes) _RecurringTile(r: r),
              ],
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final RecurringSummary summary;

  @override
  Widget build(BuildContext context) {
    final left = summary.leftToLive;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reste à vivre estimé',
                style: Theme.of(context).textTheme.labelMedium),
            Text(
              '${Fmt.euro(left)}/mois',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: left >= 0
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Revenus récurrents ${Fmt.euro(summary.monthlyIncome)} − '
              'charges récurrentes ${Fmt.euro(summary.monthlyCharges)}. '
              'Le reste finance ton quotidien variable et ton épargne.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({required this.r});
  final Recurring r;

  @override
  Widget build(BuildContext context) {
    final freq = switch (r.frequency) {
      'weekly' => 'hebdo',
      'monthly' => 'mensuel',
      _ => '~${r.occurrences}×',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            (r.isIncome ? Colors.green : Colors.indigo).withValues(alpha: 0.12),
        child: Icon(r.isIncome ? Icons.south_west : Icons.autorenew,
            size: 18, color: r.isIncome ? Colors.green.shade700 : Colors.indigo),
      ),
      title: Text(r.label),
      subtitle: Text('$freq · vu ${r.occurrences}× · '
          'dernier ${Fmt.dayMonth(r.lastDate)}'),
      trailing: Text(
        '${r.isIncome ? '+' : '-'}${Fmt.euro(r.monthlyEquivalent.abs())}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: r.isIncome ? Colors.green.shade600 : null,
        ),
      ),
    );
  }
}
