import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../assistant/llm/llm.dart';
import '../assistant/llm/llm_factory.dart';
import 'finance_repository.dart';
import 'life_profile_sheet.dart';

/// Écran d'analyse financière par Claude : où tu dépenses trop,
/// comment mieux répartir, quoi optimiser — d'après tes données + profil.
class AiAnalysisScreen extends ConsumerStatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  ConsumerState<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends ConsumerState<AiAnalysisScreen> {
  bool _loading = false;
  String? _result;
  String? _error;

  static const _system =
      'Tu es un conseiller budgétaire pédagogue intégré à MyLife. À partir '
      'des données financières et du profil de foyer fournis, produis une '
      'analyse en français, concrète et bienveillante, structurée en trois '
      'sections avec des puces :\n'
      '## Où tu dépenses trop\n## Comment mieux répartir\n## Pistes d\'optimisation\n'
      'Compare aux ordres de grandeur d\'un foyer similaire quand c\'est utile. '
      'Distingue les charges récurrentes (subies/fixes) des dépenses '
      'pilotables, et repère les abonnements optimisables. '
      'Sois précis et actionnable (montants, %). Termine par une phrase '
      'rappelant que ce sont des repères éducatifs, pas un conseil financier '
      'réglementé.';

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final context = await _buildContext();
      final client = await LlmFactory.current();
      final res = await client.complete(
        [LlmMessage.user(context)],
        system: _system,
        maxTokens: 1500,
      );
      setState(() => _result = res.text);
    } on LlmException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _buildContext() async {
    final repo = ref.read(financeRepositoryProvider);
    final now = DateTime.now();
    final summary = await repo.watchMonthSummary(now).first;
    final byCat = await repo.watchSpendByCategory(now).first;
    final goals = await repo.watchGoals().first;
    final profile = await repo.watchProfile().first;
    final capacity =
        profile.savingsCapacity ?? await repo.averageMonthlySavings();
    final recurring = await repo.recurringSummary();

    final b = StringBuffer();
    b.writeln('Analyse mes finances du mois (${Fmt.monthYear(now)}).');
    b.writeln();
    b.writeln('# Foyer');
    b.writeln('- Adultes : ${profile.adultsCount ?? '?'}, '
        'Enfants : ${profile.childrenCount ?? '?'}');
    b.writeln('- Logement : ${_housing(profile.housingType)} '
        '${_status(profile.housingStatus)}'
        '${profile.housingSurfaceM2 != null ? ', ${profile.housingSurfaceM2} m²' : ''}');
    b.writeln('- Véhicules : ${profile.vehiclesCount ?? '?'}');
    if (profile.lifeContext.isNotEmpty) {
      b.writeln('- Contexte : ${profile.lifeContext}');
    }
    b.writeln();
    b.writeln('# Ce mois-ci');
    b.writeln('- Revenus : ${Fmt.euro(summary.income)}, '
        'Dépenses : ${Fmt.euro(summary.expense)}, '
        'Solde : ${Fmt.euro(summary.balance)}');
    b.writeln('- Capacité d\'épargne estimée : ${Fmt.euro(capacity)}/mois');
    b.writeln();
    b.writeln('# Dépenses par catégorie');
    if (byCat.isEmpty) {
      b.writeln('- (aucune dépense catégorisée ce mois)');
    } else {
      for (final e in byCat) {
        final budget = e.category.monthlyBudget;
        b.writeln('- ${e.category.name} : ${Fmt.euro(e.total)}'
            '${budget != null ? ' (budget ${Fmt.euro(budget)})' : ''}');
      }
    }
    if (recurring.items.isNotEmpty) {
      b.writeln();
      b.writeln('# Récurrences détectées (équivalent mensuel)');
      b.writeln('- Revenus fixes : ${Fmt.euro(recurring.monthlyIncome)}, '
          'charges fixes : ${Fmt.euro(recurring.monthlyCharges)}, '
          'reste à vivre : ${Fmt.euro(recurring.leftToLive)}');
      for (final r in recurring.charges) {
        b.writeln('- Charge « ${r.label} » : '
            '${Fmt.euro(r.monthlyEquivalent.abs())}/mois (${r.frequency})');
      }
    }
    if (goals.isNotEmpty) {
      b.writeln();
      b.writeln('# Poches d\'épargne (nom, épargné/objectif, priorité)');
      for (final g in goals) {
        b.writeln('- ${g.name} : ${Fmt.euro(g.currentAmount)}'
            '${g.targetAmount > 0 ? '/${Fmt.euro(g.targetAmount)}' : ' (ouverte)'}'
            ', priorité ${g.weight}/5');
      }
    }
    return b.toString();
  }

  String _housing(String t) => switch (t) {
        'apartment' => 'appartement',
        'house' => 'maison',
        _ => 'logement',
      };
  String _status(String s) => switch (s) {
        'owner' => 'propriétaire',
        'renter' => 'locataire',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse IA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil de vie',
            onPressed: () => showLifeProfileSheet(context, ref),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _analyze)
              : _result == null
                  ? _Intro(onStart: _analyze)
                  : _Result(text: _result!, onRefresh: _analyze),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Analyse de tes finances',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Claude examine tes dépenses et ton profil de foyer pour te dire '
              'où tu dépenses trop, comment mieux répartir et quoi optimiser. '
              'Renseigne ton profil de vie (icône en haut) pour des repères '
              'plus justes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Lancer l\'analyse'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.text, required this.onRefresh});
  final String text;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SelectableText(text),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Relancer l\'analyse'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
