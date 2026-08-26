import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database.dart';
import 'patrimoine_repository.dart';

const _assetTypes = {
  'checking': 'Compte courant',
  'savings': 'Livret / Épargne',
  'cash': 'Espèces',
  'investment': 'Placements',
  'property': 'Immobilier / Foncier',
  'other': 'Autre actif',
};
const _liabilityTypes = {
  'loan': 'Prêt',
  'credit': 'Crédit conso',
  'other': 'Autre dette',
};

String _typeLabel(String kind, String type) =>
    (kind == 'liability' ? _liabilityTypes : _assetTypes)[type] ?? type;

IconData _typeIcon(String type) => switch (type) {
      'checking' => Icons.account_balance,
      'savings' => Icons.savings,
      'cash' => Icons.payments,
      'investment' => Icons.trending_up,
      'property' => Icons.holiday_village,
      'loan' => Icons.request_quote,
      'credit' => Icons.credit_card,
      _ => Icons.account_balance_wallet,
    };

class PatrimoineScreen extends ConsumerWidget {
  const PatrimoineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(patrimoineRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Patrimoine')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Compte'),
      ),
      body: StreamBuilder<List<Account>>(
        stream: repo.watchAccounts(),
        builder: (context, snap) {
          final accounts = snap.data ?? const [];
          if (accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Ajoute tes comptes et placements (courant, livrets, foncier, '
                  'crédits…) pour suivre ton patrimoine net et son évolution.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            );
          }
          final assets = accounts.where((a) => a.kind == 'asset').toList();
          final liabilities =
              accounts.where((a) => a.kind == 'liability').toList();
          final assetsTotal =
              assets.fold<double>(0, (s, a) => s + a.balance);
          final liabTotal =
              liabilities.fold<double>(0, (s, a) => s + a.balance);
          final net = assetsTotal - liabTotal;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _NetWorthCard(
                  net: net, assets: assetsTotal, liabilities: liabTotal),
              const SizedBox(height: 12),
              _NetWorthChart(repo: repo),
              const SizedBox(height: 12),
              if (assets.isNotEmpty) ...[
                const SectionHeader(
                    icon: Icons.savings,
                    title: 'Actifs',
                    color: Color(0xFF2E9E6B)),
                for (final a in assets)
                  _AccountTile(account: a, ref: ref),
                const SizedBox(height: 12),
              ],
              if (liabilities.isNotEmpty) ...[
                const SectionHeader(
                    icon: Icons.credit_card,
                    title: 'Passifs',
                    color: Color(0xFFE05260)),
                for (final a in liabilities)
                  _AccountTile(account: a, ref: ref),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard(
      {required this.net, required this.assets, required this.liabilities});
  final double net;
  final double assets;
  final double liabilities;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patrimoine net',
                style: Theme.of(context).textTheme.labelMedium),
            Text(
              Fmt.euro(net),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: net >= 0
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _mini(context, 'Actifs', assets, Colors.green.shade600),
                const SizedBox(width: 24),
                _mini(context, 'Passifs', liabilities,
                    Theme.of(context).colorScheme.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(BuildContext c, String label, double v, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(c).textTheme.labelSmall),
          Text(Fmt.euro(v),
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      );
}

class _NetWorthChart extends StatelessWidget {
  const _NetWorthChart({required this.repo});
  final PatrimoineRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NetWorthPoint>>(
      stream: repo.watchNetWorthPoints(),
      builder: (context, snap) {
        final points = snap.data ?? const [];
        if (points.length < 2) return const SizedBox.shrink();
        final values = points.map((p) => p.amount).toList();
        final minV = values.reduce(math.min);
        final maxV = values.reduce(math.max);
        final pad = (maxV - minV).abs() * 0.1 + 1;
        final spots = [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].amount),
        ];
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: minV - pad,
                  maxY: maxV + pad,
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
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
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.ref});
  final Account account;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final color = Color(account.color);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(_typeIcon(account.type), color: color, size: 20),
      ),
      title: Text(account.name),
      subtitle: Text('${_typeLabel(account.kind, account.type)}'
          '${account.liquid ? ' · liquide' : ''}'),
      trailing: Text(
        '${account.kind == 'liability' ? '-' : ''}${Fmt.euro(account.balance)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: account.kind == 'liability'
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      ),
      onTap: () => _showAccountSheet(context, ref, account: account),
    );
  }
}

Future<void> _showAccountSheet(BuildContext context, WidgetRef ref,
    {Account? account}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AccountForm(ref: ref, account: account),
    ),
  );
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.ref, this.account});
  final WidgetRef ref;
  final Account? account;
  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _balance = TextEditingController(
      text: widget.account != null
          ? widget.account!.balance.toStringAsFixed(2)
          : '');
  late String _kind = widget.account?.kind ?? 'asset';
  late String _type = widget.account?.type ?? 'checking';
  late bool _liquid = widget.account?.liquid ?? false;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bal = double.tryParse(_balance.text.replaceAll(',', '.')) ?? 0;
    if (_name.text.trim().isEmpty) return;
    final repo = widget.ref.read(patrimoineRepositoryProvider);
    final companion = AccountsCompanion(
      name: Value(_name.text.trim()),
      kind: Value(_kind),
      type: Value(_type),
      balance: Value(bal),
      liquid: Value(_kind == 'asset' && _liquid),
    );
    if (widget.account == null) {
      await repo.addAccount(AccountsCompanion.insert(
        name: _name.text.trim(),
        kind: Value(_kind),
        type: Value(_type),
        balance: Value(bal),
        liquid: Value(_kind == 'asset' && _liquid),
      ));
    } else {
      await repo.updateAccount(widget.account!.id, companion);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final types = _kind == 'liability' ? _liabilityTypes : _assetTypes;
    if (!types.containsKey(_type)) _type = types.keys.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.account == null ? 'Nouveau compte' : 'Modifier',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (widget.account != null)
                  IconButton(
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: 'Archiver',
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await widget.ref
                          .read(patrimoineRepositoryProvider)
                          .archiveAccount(widget.account!.id);
                      nav.pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'asset', label: Text('Actif')),
                ButtonSegment(value: 'liability', label: Text('Passif / dette')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _type = (_kind == 'liability' ? _liabilityTypes : _assetTypes)
                    .keys
                    .first;
              }),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Nom', prefixIcon: Icon(Icons.label_outline)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Type', prefixIcon: Icon(Icons.category)),
              items: [
                for (final e in types.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balance,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _kind == 'liability'
                    ? 'Capital restant dû (€)'
                    : 'Solde (€)',
                prefixIcon: const Icon(Icons.euro),
              ),
            ),
            if (_kind == 'asset')
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compte liquide'),
                subtitle:
                    const Text('Compté dans la prévision de trésorerie'),
                value: _liquid,
                onChanged: (v) => setState(() => _liquid = v ?? false),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _submit, child: const Text('Enregistrer')),
            ),
          ],
        ),
      ),
    );
  }
}
