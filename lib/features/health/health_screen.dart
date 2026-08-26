import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import 'health_dialogs.dart';
import 'health_pdf.dart';
import 'health_repository.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Santé'),
          actions: [
            Consumer(
              builder: (context, ref, _) => IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF médecin',
                onPressed: () => showExportHealthPdf(context, ref),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sommeil'),
              Tab(text: 'Douleurs'),
              Tab(text: 'Cachets'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SleepTab(),
            _PainTab(),
            _MedsTab(),
          ],
        ),
      ),
    );
  }
}

// ============================ SOMMEIL ============================

class _SleepTab extends ConsumerWidget {
  const _SleepTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(healthRepositoryProvider);
    return Scaffold(
      body: StreamBuilder<List<SleepEntry>>(
        stream: repo.watchSleep(),
        builder: (context, snap) {
          final entries = snap.data ?? const [];
          if (entries.isEmpty) {
            return const _EmptyHint(
                'Aucune nuit enregistrée. Ajoute-en une avec « + ».');
          }
          final avg = entries.take(7).fold<int>(
                  0, (s, e) => s + e.durationMinutes) ~/
              (entries.length < 7 ? entries.length : 7);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.bedtime, color: Colors.indigo),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Moyenne (7 derniers)',
                                style:
                                    Theme.of(context).textTheme.labelMedium),
                            Text(Fmt.duration(avg),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SleepChart(entries: entries.take(14).toList().reversed.toList()),
              const SizedBox(height: 12),
              for (final e in entries)
                Dismissible(
                  key: ValueKey('sleep_${e.id}'),
                  direction: DismissDirection.endToStart,
                  background: _delBg(context),
                  onDismissed: (_) => repo.deleteSleep(e.id),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                      child: Text(Fmt.duration(e.durationMinutes),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.indigo)),
                    ),
                    title: Text(Fmt.fullDate(e.date)),
                    subtitle: Text(
                        '${Fmt.time(e.bedTime)} → ${Fmt.time(e.wakeTime)}  ·  '
                        '${'★' * e.quality}${'☆' * (5 - e.quality)}'),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddSleepSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuit'),
      ),
    );
  }
}

class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.entries});
  final List<SleepEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) return const SizedBox.shrink();
    final spots = [
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].durationMinutes / 60),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: 0,
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
                    reservedSize: 30,
                    interval: 2,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}h',
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.indigo,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.indigo.withValues(alpha: 0.12),
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

// ============================ DOULEURS ============================

class _PainTab extends ConsumerWidget {
  const _PainTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(healthRepositoryProvider);
    return Scaffold(
      body: StreamBuilder<List<PainEntry>>(
        stream: repo.watchPain(),
        builder: (context, snap) {
          final entries = snap.data ?? const [];
          if (entries.isEmpty) {
            return const _EmptyHint(
                'Aucune douleur notée. Enregistre-en une avec « + ».');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final e in entries)
                Dismissible(
                  key: ValueKey('pain_${e.id}'),
                  direction: DismissDirection.endToStart,
                  background: _delBg(context),
                  onDismissed: (_) => repo.deletePain(e.id),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _painColor(e.intensity)
                          .withValues(alpha: 0.18),
                      child: Text('${e.intensity}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _painColor(e.intensity))),
                    ),
                    title: Text(
                        e.location.isEmpty ? 'Douleur' : e.location),
                    subtitle: Text(e.note.isEmpty
                        ? '${Fmt.dayMonth(e.at)} · ${Fmt.time(e.at)}'
                        : '${e.note}\n${Fmt.dayMonth(e.at)} · ${Fmt.time(e.at)}'),
                    isThreeLine: e.note.isNotEmpty,
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddPainSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Douleur'),
      ),
    );
  }
}

Color _painColor(int intensity) {
  if (intensity <= 3) return Colors.green;
  if (intensity <= 6) return Colors.orange;
  return Colors.red;
}

// ============================ CACHETS ============================

class _MedsTab extends ConsumerWidget {
  const _MedsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(healthRepositoryProvider);
    return Scaffold(
      body: StreamBuilder<List<Medication>>(
        stream: repo.watchMedications(),
        builder: (context, snap) {
          final meds = snap.data ?? const [];
          if (meds.isEmpty) {
            return const _EmptyHint(
                'Ajoute un médicament pour suivre tes prises et être rappelé.');
          }
          return StreamBuilder<Map<int, int>>(
            stream: repo.watchTodayIntakeCounts(),
            builder: (context, countSnap) {
              final counts = countSnap.data ?? const {};
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in meds)
                    _MedCard(med: m, todayCount: counts[m.id] ?? 0),
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddMedicationSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Médicament'),
      ),
    );
  }
}

class _MedCard extends ConsumerWidget {
  const _MedCard({required this.med, required this.todayCount});
  final Medication med;
  final int todayCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(healthRepositoryProvider);
    final times = med.scheduleTimes.split(',').where((s) => s.isNotEmpty);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (med.dosage.isNotEmpty)
                        Text(med.dosage,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'reminders') {
                      repo.toggleReminders(med, !med.remindersOn);
                    } else if (v == 'delete') {
                      repo.deactivateMedication(med);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'reminders',
                      child: Text(med.remindersOn
                          ? 'Couper les rappels'
                          : 'Activer les rappels'),
                    ),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
            if (times.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in times)
                    Chip(
                      label: Text(t),
                      avatar: Icon(
                        med.remindersOn
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        size: 16,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Aujourd\'hui : $todayCount prise(s)',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => repo.logIntake(med.id),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('J\'ai pris'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ COMMUN ============================

Widget _delBg(BuildContext context) => Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Icon(Icons.delete_outline),
    );

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline)),
        ),
      );
}
