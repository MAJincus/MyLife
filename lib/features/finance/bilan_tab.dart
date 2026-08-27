import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database.dart';
import 'finance_history.dart';
import 'finance_repository.dart';
import 'patrimoine_repository.dart';

final _statsProvider = FutureProvider<List<MonthStat>>((ref) {
  return ref.watch(financeRepositoryProvider).monthlyStats(months: 6);
});

/// Onglet « Bilan » : KPI du mois + évolution mois après mois.
class BilanTab extends ConsumerWidget {
  const BilanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_statsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_statsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (stats) {
          if (stats.every((s) => s.income == 0 && s.expense == 0)) {
            return ListView(children: const [
              Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Pas encore de données. Ajoute des transactions ou importe '
                  'un relevé : le bilan se remplira mois après mois.',
                  textAlign: TextAlign.center,
                ),
              ),
            ]);
          }
          final current = stats.last;
          final previous = stats.length > 1 ? stats[stats.length - 2] : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionHeader(
                  icon: Icons.speed,
                  title: 'KPI — ${Fmt.monthYear(DateTime(current.year, current.month))}',
                  color: ModuleColors.finance),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _KpiCard(
                    label: 'Taux d\'épargne',
                    value: '${(current.savingsRate * 100).round()} %',
                    deltaPoints:
                        previous != null
                            ? (current.savingsRate - previous.savingsRate) * 100
                            : null,
                    goodWhenUp: true,
                    isPoints: true,
                  ),
                  _KpiCard(
                    label: 'Solde du mois',
                    value: Fmt.euro(current.balance),
                    deltaPct: previous != null
                        ? relativeDelta(current.balance, previous.balance)
                        : null,
                    goodWhenUp: true,
                  ),
                  _KpiCard(
                    label: 'Revenus',
                    value: Fmt.euro(current.income),
                    deltaPct: previous != null
                        ? relativeDelta(current.income, previous.income)
                        : null,
                    goodWhenUp: true,
                  ),
                  _KpiCard(
                    label: 'Dépenses',
                    value: Fmt.euro(current.expense),
                    deltaPct: previous != null
                        ? relativeDelta(current.expense, previous.expense)
                        : null,
                    goodWhenUp: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader(
                  icon: Icons.bar_chart,
                  title: 'Revenus vs dépenses',
                  color: ModuleColors.finance),
              const SizedBox(height: 8),
              _IncomeExpenseChart(stats: stats),
              const SizedBox(height: 20),
              const SectionHeader(
                  icon: Icons.show_chart, title: 'Taux d\'épargne'),
              const SizedBox(height: 8),
              _SavingsRateChart(stats: stats),
              const SizedBox(height: 20),
              const SectionHeader(
                  icon: Icons.account_balance, title: 'Patrimoine net'),
              const SizedBox(height: 8),
              _NetWorthMini(ref: ref),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.goodWhenUp,
    this.deltaPct,
    this.deltaPoints,
    this.isPoints = false,
  });
  final String label;
  final String value;
  final bool goodWhenUp;
  final double? deltaPct; // variation relative (0.1 = +10%)
  final double? deltaPoints; // variation en points (taux d'épargne)
  final bool isPoints;

  @override
  Widget build(BuildContext context) {
    final delta = isPoints ? deltaPoints : deltaPct;
    Widget? deltaWidget;
    if (delta != null && delta.abs() > 0.0001) {
      final up = delta > 0;
      final good = up == goodWhenUp;
      final color = good ? Colors.green.shade600 : Theme.of(context).colorScheme.error;
      final txt = isPoints
          ? '${up ? '+' : ''}${delta.round()} pts'
          : '${up ? '+' : ''}${(delta * 100).round()} %';
      deltaWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13, color: color),
          Text(txt, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                if (deltaWidget != null) deltaWidget else
                  Text('vs mois précédent',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({required this.stats});
  final List<MonthStat> stats;

  @override
  Widget build(BuildContext context) {
    final maxV = stats
        .map((s) => math.max(s.income, s.expense))
        .fold<double>(0, math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxV * 1.2 + 1,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= stats.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(stats[i].label,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < stats.length; i++)
                  BarChartGroupData(x: i, barsSpace: 2, barRods: [
                    BarChartRodData(
                        toY: stats[i].income,
                        color: Colors.green.shade500,
                        width: 7,
                        borderRadius: BorderRadius.circular(2)),
                    BarChartRodData(
                        toY: stats[i].expense,
                        color: Colors.red.shade400,
                        width: 7,
                        borderRadius: BorderRadius.circular(2)),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavingsRateChart extends StatelessWidget {
  const _SavingsRateChart({required this.stats});
  final List<MonthStat> stats;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < stats.length; i++)
        FlSpot(i.toDouble(), (stats[i].savingsRate * 100).clamp(-100, 100)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, _) =>
                        Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= stats.length) return const SizedBox();
                      return Text(stats[i].label,
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: ModuleColors.finance,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: ModuleColors.finance.withValues(alpha: 0.12),
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

class _NetWorthMini extends StatelessWidget {
  const _NetWorthMini({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NetWorthPoint>>(
      stream: ref.watch(patrimoineRepositoryProvider).watchNetWorthPoints(),
      builder: (context, snap) {
        final points = snap.data ?? const [];
        if (points.length < 2) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Renseigne tes comptes dans Patrimoine pour suivre l\'évolution '
                'de ton patrimoine net ici.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          );
        }
        final values = points.map((p) => p.amount).toList();
        final minV = values.reduce(math.min);
        final maxV = values.reduce(math.max);
        final pad = (maxV - minV).abs() * 0.1 + 1;
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: minV - pad,
                  maxY: maxV + pad,
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].amount),
                      ],
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
      },
    );
  }
}
