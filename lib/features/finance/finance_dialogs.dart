import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import 'finance_repository.dart';

/// Feuille modale d'ajout de transaction (dépense ou revenu).
Future<void> showAddTransactionSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddTransactionForm(ref: ref),
    ),
  );
}

class _AddTransactionForm extends StatefulWidget {
  const _AddTransactionForm({required this.ref});
  final WidgetRef ref;

  @override
  State<_AddTransactionForm> createState() => _AddTransactionFormState();
}

class _AddTransactionFormState extends State<_AddTransactionForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _kind = 'expense';
  int? _categoryId;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    final repo = widget.ref.read(financeRepositoryProvider);
    await repo.addTransaction(TransactionsCompanion.insert(
      amount: value,
      kind: Value(_kind),
      categoryId: Value(_categoryId),
      date: _date,
      note: Value(_note.text.trim()),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.ref.read(financeRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouvelle transaction',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Dépense')),
              ButtonSegment(value: 'income', label: Text('Revenu')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Montant (€)',
              prefixIcon: Icon(Icons.euro),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Category>>(
            stream: repo.watchCategories(),
            builder: (context, snap) {
              final cats = (snap.data ?? const <Category>[])
                  .where((c) => c.kind == _kind)
                  .toList();
              return DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  for (final c in cats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optionnel)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(Fmt.fullDate(_date)),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille d'ajout d'un plan d'épargne.
Future<void> showAddGoalSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddGoalForm(ref: ref),
    ),
  );
}

class _AddGoalForm extends StatefulWidget {
  const _AddGoalForm({required this.ref});
  final WidgetRef ref;
  @override
  State<_AddGoalForm> createState() => _AddGoalFormState();
}

class _AddGoalFormState extends State<_AddGoalForm> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _initial = TextEditingController();
  DateTime? _targetDate;
  int _weight = 3;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    // Objectif optionnel : vide = poche "ouverte" (target 0).
    final target = double.tryParse(_target.text.replaceAll(',', '.')) ?? 0;
    final initial = double.tryParse(_initial.text.replaceAll(',', '.')) ?? 0;
    final repo = widget.ref.read(financeRepositoryProvider);
    await repo.addGoal(SavingsGoalsCompanion.insert(
      name: _name.text.trim(),
      targetAmount: Value(target),
      currentAmount: Value(initial),
      targetDate: Value(_targetDate),
      weight: Value(_weight),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouvelle poche d\'épargne',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom (ex. Vacances 2027)',
              prefixIcon: Icon(Icons.savings),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Objectif (€) — vide = poche ouverte',
              prefixIcon: Icon(Icons.flag),
            ),
          ),
          const SizedBox(height: 12),
          Text('Priorité : $_weight / 5',
              style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: _weight.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_weight',
            onChanged: (v) => setState(() => _weight = v.round()),
          ),
          TextField(
            controller: _initial,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Déjà épargné (optionnel)',
              prefixIcon: Icon(Icons.account_balance),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_targetDate == null
                ? 'Échéance (optionnel)'
                : 'Échéance : ${Fmt.fullDate(_targetDate!)}'),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 180)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Créer la poche'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialogue pour ajouter de l'épargne à un projet.
Future<void> showContributeDialog(
    BuildContext context, WidgetRef ref, SavingsGoal goal) {
  final controller = TextEditingController();
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Épargner pour « ${goal.name} »'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Montant (€)',
          prefixIcon: Icon(Icons.euro),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () async {
            final v =
                double.tryParse(controller.text.replaceAll(',', '.'));
            if (v != null && v > 0) {
              await ref
                  .read(financeRepositoryProvider)
                  .contribute(goal.id, v);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Ajouter'),
        ),
      ],
    ),
  );
}
