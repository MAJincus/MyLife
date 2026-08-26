import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'finance_repository.dart';
import 'patrimoine_repository.dart';
import 'treasury.dart';

final treasuryForecastProvider = FutureProvider<TreasuryForecast>((ref) async {
  final liquid = await ref.watch(patrimoineRepositoryProvider).liquidTotal();
  return ref
      .watch(financeRepositoryProvider)
      .treasuryForecast(liquid, liquid > 0);
});

/// Carte compacte de prévision fin de mois pour l'onglet Dépenses.
class TreasuryCard extends ConsumerWidget {
  const TreasuryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(treasuryForecastProvider).valueOrNull;
    if (f == null) return const SizedBox.shrink();
    if (!f.hasStartBalance && f.netChange == 0) return const SizedBox.shrink();

    final positive = f.hasStartBalance ? f.endBalance >= 0 : f.netChange >= 0;
    final color = positive
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.error;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TreasuryScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.indigo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        f.hasStartBalance
                            ? 'Solde estimé fin de mois'
                            : 'Variation attendue d\'ici la fin du mois',
                        style: Theme.of(context).textTheme.labelMedium),
                    Text(
                      f.hasStartBalance
                          ? Fmt.euro(f.endBalance)
                          : '${f.netChange >= 0 ? '+' : ''}${Fmt.euro(f.netChange)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold, color: color),
                    ),
                    if (f.remainingDays > 0)
                      Text(
                        'Reste à dépenser ~${Fmt.euro(f.safeToSpendPerDay)}/jour '
                        '(${f.remainingDays} j)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran détaillé de la prévision de trésorerie.
class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treasuryForecastProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prévision fin de mois'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(treasuryForecastProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (f) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        f.hasStartBalance
                            ? 'Solde projeté au ${_lastDay()}'
                            : 'Variation nette attendue',
                        style: Theme.of(context).textTheme.labelMedium),
                    Text(
                      f.hasStartBalance
                          ? Fmt.euro(f.endBalance)
                          : '${f.netChange >= 0 ? '+' : ''}${Fmt.euro(f.netChange)}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: (f.hasStartBalance
                                    ? f.endBalance
                                    : f.netChange) >=
                                    0
                                ? Colors.green.shade700
                                : Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _line(context, 'Solde de départ (comptes liquides)',
                f.hasStartBalance ? Fmt.euro(f.startBalance) : '—'),
            _line(context, 'Revenus récurrents à venir',
                '+${Fmt.euro(f.expectedIncome)}', Colors.green.shade600),
            _line(context, 'Charges récurrentes à venir',
                '-${Fmt.euro(f.expectedCharges)}',
                Theme.of(context).colorScheme.error),
            _line(context, 'Dépenses variables estimées',
                '-${Fmt.euro(f.expectedVariable)}',
                Theme.of(context).colorScheme.error),
            const Divider(),
            _line(
                context,
                f.hasStartBalance ? 'Solde fin de mois' : 'Variation nette',
                f.hasStartBalance
                    ? Fmt.euro(f.endBalance)
                    : '${f.netChange >= 0 ? '+' : ''}${Fmt.euro(f.netChange)}',
                null,
                true),
            const SizedBox(height: 16),
            if (f.remainingDays > 0)
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.4),
                child: ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: Text(
                      'Reste à dépenser ~${Fmt.euro(f.safeToSpendPerDay)}/jour'),
                  subtitle: Text('sur les ${f.remainingDays} jours restants, '
                      'pour finir le mois à l\'équilibre'),
                ),
              ),
            if (!f.hasStartBalance) ...[
              const SizedBox(height: 12),
              Text(
                'Ajoute un compte marqué « liquide » dans Patrimoine pour '
                'projeter ton solde réel plutôt que la simple variation.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _lastDay() {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month + 1, 0);
    return Fmt.dayMonth(last);
  }

  Widget _line(BuildContext context, String label, String value,
      [Color? color, bool bold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }
}
