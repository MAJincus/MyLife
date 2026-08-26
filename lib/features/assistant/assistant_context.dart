import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../diet/diet_repository.dart';
import '../finance/finance_repository.dart';
import '../health/health_repository.dart';
import '../agenda/agenda_repository.dart';

/// Construit un résumé compact et à jour des données de l'utilisateur,
/// injecté dans le prompt système pour des conseils contextualisés.
///
/// Toutes les données restent locales : ce résumé n'est envoyé à l'API Claude
/// que lorsque l'utilisateur pose une question.
Future<String> buildPersonalContext(WidgetRef ref) async {
  final now = DateTime.now();
  final buf = StringBuffer();
  buf.writeln('DONNÉES PERSONNELLES DE L\'UTILISATEUR (${Fmt.fullDate(now)}) :');

  await _financeSection(ref, now, buf);
  await _dietSection(ref, now, buf);
  await _healthSection(ref, buf);
  await _agendaSection(ref, buf);

  buf.writeln();
  buf.writeln('Utilise ces chiffres pour personnaliser tes réponses '
      '(montants en euros, calories, sommeil...). Ne les répète pas '
      'tels quels sauf si pertinent.');
  return buf.toString();
}

Future<void> _financeSection(
    WidgetRef ref, DateTime now, StringBuffer buf) async {
  final repo = ref.read(financeRepositoryProvider);
  try {
    final summary = await repo.watchMonthSummary(now).first;
    final byCat = await repo.watchSpendByCategory(now).first;
    final goals = await repo.watchGoals().first;

    buf.writeln();
    buf.writeln('# Finances (mois en cours)');
    buf.writeln('- Revenus : ${Fmt.euro(summary.income)}, '
        'Dépenses : ${Fmt.euro(summary.expense)}, '
        'Solde : ${Fmt.euro(summary.balance)}');
    if (byCat.isNotEmpty) {
      final top = byCat
          .take(5)
          .map((e) => '${e.category.name} ${Fmt.euro(e.total)}')
          .join(', ');
      buf.writeln('- Principales dépenses : $top');
      final over = byCat.where((e) =>
          e.category.monthlyBudget != null &&
          e.total > e.category.monthlyBudget!);
      for (final e in over) {
        buf.writeln('- ⚠️ Budget dépassé sur ${e.category.name} : '
            '${Fmt.euro(e.total)} / ${Fmt.euro(e.category.monthlyBudget!)}');
      }
    }
    for (final g in goals) {
      if (g.targetAmount > 0) {
        final pct = (g.currentAmount / g.targetAmount * 100).round();
        buf.writeln('- Poche « ${g.name} » (prio ${g.weight}/5) : '
            '${Fmt.euro(g.currentAmount)}/${Fmt.euro(g.targetAmount)} ($pct%)');
      } else {
        buf.writeln('- Poche « ${g.name} » (prio ${g.weight}/5, ouverte) : '
            '${Fmt.euro(g.currentAmount)} épargnés');
      }
    }

    // Récurrences (revenus/charges fixes + reste à vivre).
    final rec = await repo.recurringSummary();
    if (rec.items.isNotEmpty) {
      buf.writeln('- Récurrents : revenus fixes ${Fmt.euro(rec.monthlyIncome)}, '
          'charges fixes ${Fmt.euro(rec.monthlyCharges)}, '
          'reste à vivre ${Fmt.euro(rec.leftToLive)}/mois');
    }

    // Profil de foyer (pour contextualiser les conseils).
    final profile = await repo.watchProfile().first;
    if (profile.adultsCount != null || profile.childrenCount != null) {
      buf.writeln('- Foyer : ${profile.adultsCount ?? '?'} adulte(s), '
          '${profile.childrenCount ?? 0} enfant(s)'
          '${profile.housingType.isNotEmpty ? ', ${profile.housingType == 'house' ? 'maison' : 'appartement'}' : ''}'
          '${profile.housingSurfaceM2 != null ? ' ${profile.housingSurfaceM2} m²' : ''}'
          '${profile.vehiclesCount != null ? ', ${profile.vehiclesCount} véhicule(s)' : ''}.');
    }
  } catch (_) {}
}

Future<void> _dietSection(
    WidgetRef ref, DateTime now, StringBuffer buf) async {
  final repo = ref.read(dietRepositoryProvider);
  try {
    final profile = await repo.watchProfile().first;
    final nut = await repo.watchDayNutrition(now).first;
    final weights = await repo.watchWeights(limit: 30).first;

    buf.writeln();
    buf.writeln('# Diète & poids');
    buf.writeln('- Aujourd\'hui : ${nut.kcal.round()} kcal '
        '(P ${nut.protein.round()}g / G ${nut.carbs.round()}g / '
        'L ${nut.fat.round()}g)');
    if (profile.dailyKcalTarget != null) {
      buf.writeln('- Objectif calorique : ${profile.dailyKcalTarget} kcal/j '
          '(but : ${_goalLabel(profile.dietGoal)})');
    }
    if (weights.isNotEmpty) {
      final latest = weights.first.weightKg;
      final oldest = weights.last.weightKg;
      final delta = latest - oldest;
      buf.writeln('- Poids actuel : ${latest.toStringAsFixed(1)} kg '
          '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg sur '
          '${weights.length} mesures)');
      if (profile.targetWeightKg != null) {
        buf.writeln('- Poids cible : '
            '${profile.targetWeightKg!.toStringAsFixed(1)} kg');
      }
    }
  } catch (_) {}
}

Future<void> _healthSection(WidgetRef ref, StringBuffer buf) async {
  final repo = ref.read(healthRepositoryProvider);
  try {
    final sleep = await repo.watchSleep(limit: 7).first;
    final pain = await repo.watchPain(limit: 14).first;
    final meds = await repo.watchMedications().first;
    final intake = await repo.watchTodayIntakeCounts().first;

    buf.writeln();
    buf.writeln('# Santé');
    if (sleep.isNotEmpty) {
      final avg =
          sleep.fold<int>(0, (s, e) => s + e.durationMinutes) ~/ sleep.length;
      final avgQ =
          sleep.fold<int>(0, (s, e) => s + e.quality) / sleep.length;
      buf.writeln('- Sommeil (7 dernières nuits) : moyenne '
          '${Fmt.duration(avg)}, qualité ${avgQ.toStringAsFixed(1)}/5');
      buf.writeln('- Dernière nuit : '
          '${Fmt.duration(sleep.first.durationMinutes)}');
    }
    if (pain.isNotEmpty) {
      final avgP =
          pain.fold<int>(0, (s, e) => s + e.intensity) / pain.length;
      buf.writeln('- Douleurs récentes : ${pain.length} épisodes, '
          'intensité moyenne ${avgP.toStringAsFixed(1)}/10 '
          '(dernière : ${pain.first.location.isEmpty ? "?" : pain.first.location} '
          'à ${pain.first.intensity}/10)');
    }
    for (final m in meds) {
      final taken = intake[m.id] ?? 0;
      buf.writeln('- Médicament « ${m.name} » '
          '${m.dosage.isEmpty ? "" : "(${m.dosage}) "}: '
          '$taken prise(s) aujourd\'hui');
    }
  } catch (_) {}
}

Future<void> _agendaSection(WidgetRef ref, StringBuffer buf) async {
  final repo = ref.read(agendaRepositoryProvider);
  try {
    final upcoming = await repo.watchUpcoming().first;
    if (upcoming.isEmpty) return;
    buf.writeln();
    buf.writeln('# Rappels à venir');
    for (final r in upcoming.take(5)) {
      buf.writeln('- ${r.title} — ${Fmt.dayMonth(r.dueAt)} ${Fmt.time(r.dueAt)}');
    }
  } catch (_) {}
}

String _goalLabel(String goal) => switch (goal) {
      'lose' => 'perdre du poids',
      'gain' => 'prendre du poids',
      _ => 'maintenir',
    };
