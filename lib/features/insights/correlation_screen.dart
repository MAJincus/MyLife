import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assistant/llm/llm.dart';
import '../assistant/llm/llm_factory.dart';
import '../diet/diet_repository.dart';
import '../finance/finance_repository.dart';
import '../health/health_repository.dart';
import 'correlations.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Séries journalières de toutes les métriques, sur ~90 jours.
final correlationSeriesProvider =
    FutureProvider<Map<String, Map<DateTime, double>>>((ref) async {
  final health = ref.watch(healthRepositoryProvider);
  final diet = ref.watch(dietRepositoryProvider);
  final finance = ref.watch(financeRepositoryProvider);

  final now = DateTime.now();
  final start = _day(now).subtract(const Duration(days: 90));

  final sleep = await health.sleepBetween(start, now);
  final pain = await health.painBetween(start, now);
  final meals = await diet.mealsBetween(start, now);
  final activities = await diet.activitiesBetween(start, now);
  final weights = await diet.weightsBetween(start, now);
  final expenses = await finance.expensesBetween(start, now);

  final sleepH = <DateTime, double>{};
  final sleepQ = <DateTime, double>{};
  for (final s in sleep) {
    sleepH[_day(s.date)] = s.durationMinutes / 60.0;
    sleepQ[_day(s.date)] = s.quality.toDouble();
  }

  final painByDay = <DateTime, List<int>>{};
  for (final p in pain) {
    painByDay.putIfAbsent(_day(p.at), () => []).add(p.intensity);
  }
  final painAvg = {
    for (final e in painByDay.entries)
      e.key: e.value.reduce((a, b) => a + b) / e.value.length,
  };

  final kcal = <DateTime, double>{};
  for (final m in meals) {
    kcal[_day(m.at)] = (kcal[_day(m.at)] ?? 0) + m.kcal;
  }

  final activity = <DateTime, double>{};
  for (final a in activities) {
    activity[_day(a.at)] = (activity[_day(a.at)] ?? 0) + a.durationMinutes;
  }

  final weight = <DateTime, double>{};
  for (final w in weights) {
    weight[_day(w.date)] = w.weightKg;
  }

  final expense = <DateTime, double>{};
  for (final t in expenses) {
    expense[_day(t.date)] = (expense[_day(t.date)] ?? 0) + t.amount;
  }

  final series = <String, Map<DateTime, double>>{
    'Sommeil (h)': sleepH,
    'Qualité sommeil': sleepQ,
    'Douleur (0-10)': painAvg,
    'Calories': kcal,
    'Activité (min)': activity,
    'Poids (kg)': weight,
    'Dépenses (€)': expense,
  };
  series.removeWhere((_, v) => v.length < 4);
  return series;
});

final correlationsProvider = FutureProvider<List<Correlation>>((ref) async {
  final series = await ref.watch(correlationSeriesProvider.future);
  return computeCorrelations(series);
});

class CorrelationScreen extends ConsumerStatefulWidget {
  const CorrelationScreen({super.key});

  @override
  ConsumerState<CorrelationScreen> createState() => _CorrelationScreenState();
}

class _CorrelationScreenState extends ConsumerState<CorrelationScreen> {
  bool _interpreting = false;
  String? _interpretation;

  Future<void> _interpret(List<Correlation> correlations) async {
    setState(() => _interpreting = true);
    final lines = correlations.take(8).map(describeCorrelation).join('\n');
    try {
      final client = await LlmFactory.current();
      final res = await client.complete(
        [LlmMessage.user('Corrélations observées :\n$lines')],
        system:
            'Tu es un coach santé/finances pédagogue. On te donne des '
            'corrélations statistiques observées dans les données de '
            'l\'utilisateur. Explique en français, avec prudence, ce qu\'elles '
            'pourraient signifier et 2-3 pistes d\'action concrètes. Rappelle '
            'que corrélation n\'est pas causalité et que ce ne sont pas des '
            'conseils médicaux.',
        maxTokens: 1000,
      );
      setState(() => _interpretation = res.text);
    } on LlmException catch (e) {
      setState(() => _interpretation = '⚠️ ${e.message}');
    } finally {
      setState(() => _interpreting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(correlationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corrélations & insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(correlationSeriesProvider);
              ref.invalidate(correlationsProvider);
              setState(() => _interpretation = null);
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (correlations) {
          if (correlations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Pas encore de lien significatif détecté.\n\n'
                  'Continue à noter ton sommeil, tes repas, tes douleurs, ton '
                  'activité et tes dépenses sur quelques semaines : MyLife '
                  'cherchera les corrélations entre eux.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Liens repérés dans tes données. Attention : une corrélation '
                'n\'est pas forcément une cause.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final c in correlations) _CorrelationCard(c: c),
              const SizedBox(height: 16),
              if (_interpreting)
                const Center(child: CircularProgressIndicator())
              else if (_interpretation != null)
                Card(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(_interpretation!),
                  ),
                )
              else
                Center(
                  child: FilledButton.icon(
                    onPressed: () => _interpret(correlations),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Interpréter avec l\'IA'),
                  ),
                ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

class _CorrelationCard extends StatelessWidget {
  const _CorrelationCard({required this.c});
  final Correlation c;

  @override
  Widget build(BuildContext context) {
    final color = c.strength >= 0.6
        ? (c.isPositive ? Colors.deepOrange : Colors.teal)
        : Theme.of(context).colorScheme.outline;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(c.isPositive ? Icons.trending_up : Icons.trending_down,
                color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(describeCorrelation(c))),
          ],
        ),
      ),
    );
  }
}
