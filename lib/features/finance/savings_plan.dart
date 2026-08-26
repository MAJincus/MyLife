import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import 'finance_repository.dart';
import 'pocket_icons.dart';
import 'savings_allocation.dart';

/// Capacité d'épargne auto-estimée (moyenne revenus−dépenses sur 3 mois).
final autoCapacityProvider = FutureProvider<double>((ref) {
  return ref.watch(financeRepositoryProvider).averageMonthlySavings();
});

/// Carte « Plan mensuel » : capacité + répartition suggérée par poche.
class SavingsPlanCard extends ConsumerWidget {
  const SavingsPlanCard({super.key, required this.pockets});
  final List<SavingsGoal> pockets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(financeRepositoryProvider);
    final autoAsync = ref.watch(autoCapacityProvider);

    return StreamBuilder<ProfileData>(
      stream: repo.watchProfile(),
      builder: (context, profileSnap) {
        final manual = profileSnap.data?.savingsCapacity;
        final auto = autoAsync.valueOrNull ?? 0;
        final capacity = manual ?? auto;

        final alloc = allocateSavings(capacity, [
          for (final g in pockets)
            Pocket(
              id: g.id,
              name: g.name,
              weight: g.weight,
              remaining: g.targetAmount > 0
                  ? g.targetAmount - g.currentAmount
                  : null,
            ),
        ]);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pie_chart_outline, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text('Plan du mois',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          _editCapacity(context, ref, capacity, manual != null),
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
                Text(
                  'Capacité d\'épargne : ${Fmt.euro(capacity)}/mois'
                  '${manual == null ? ' (estimée)' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (capacity <= 0)
                  Text(
                    'Renseigne tes revenus/dépenses ou fixe une capacité pour '
                    'voir la répartition.',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  )
                else
                  for (final g in pockets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(pocketIcon(g.icon),
                              size: 18, color: Color(g.color)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(g.name)),
                          Text(
                            Fmt.euro(alloc[g.id] ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 4),
                Text(
                  'À toi de faire les virements. Ajuste les poids de chaque '
                  'poche pour changer la répartition.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editCapacity(
      BuildContext context, WidgetRef ref, double current, bool isManual) async {
    final controller =
        TextEditingController(text: current > 0 ? current.toStringAsFixed(0) : '');
    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Capacité d\'épargne mensuelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Combien peux-tu mettre de côté chaque mois ? Laisse vide '
                'pour l\'estimer automatiquement depuis tes finances.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant (€/mois)',
                prefixIcon: Icon(Icons.euro),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, -1.0), // sentinelle = auto
            child: const Text('Auto'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final repo = ref.read(financeRepositoryProvider);
    await repo.updateProfile(ProfileCompanion(
      savingsCapacity: Value(result < 0 ? null : result),
    ));
  }
}
