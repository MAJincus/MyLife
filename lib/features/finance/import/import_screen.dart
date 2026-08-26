import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../finance_repository.dart';
import 'bank_csv.dart';
import 'categorizer.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

enum _AmountMode { single, debitCredit }

class _ImportScreenState extends ConsumerState<ImportScreen> {
  CsvTable? _table;
  String _fileName = '';
  bool _hasHeader = true;
  _AmountMode _mode = _AmountMode.single;
  int _dateCol = -1, _labelCol = -1, _amountCol = -1, _debitCol = -1, _creditCol = -1;
  bool _autoCat = true;
  bool _importing = false;

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    final content = BankCsv.decodeBytes(bytes);
    final table = BankCsv.parse(content);
    final headers = table.rows.isNotEmpty ? table.rows.first : <String>[];
    final guess = BankCsv.guessColumns(headers);
    setState(() {
      _fileName = res!.files.single.name;
      _table = table;
      _dateCol = guess.date;
      _labelCol = guess.label;
      if (guess.debit >= 0 && guess.credit >= 0) {
        _mode = _AmountMode.debitCredit;
        _debitCol = guess.debit;
        _creditCol = guess.credit;
      } else {
        _mode = _AmountMode.single;
        _amountCol = guess.amount;
      }
    });
  }

  String _cell(List<String> row, int i) =>
      (i >= 0 && i < row.length) ? row[i] : '';

  String _colLabel(int i) {
    final t = _table!;
    if (_hasHeader && t.rows.isNotEmpty && i < t.rows.first.length) {
      final h = t.rows.first[i].trim();
      if (h.isNotEmpty) return h;
    }
    return 'Colonne ${i + 1}';
  }

  List<ParsedTx> _build() {
    final t = _table;
    if (t == null) return [];
    final dataRows = _hasHeader ? t.rows.skip(1) : t.rows;
    final result = <ParsedTx>[];
    for (final r in dataRows) {
      final date = BankCsv.parseDate(_cell(r, _dateCol));
      if (date == null) continue;
      final label = _cell(r, _labelCol);
      double? amount;
      if (_mode == _AmountMode.single) {
        amount = BankCsv.parseAmount(_cell(r, _amountCol));
      } else {
        final deb = BankCsv.parseAmount(_cell(r, _debitCol));
        final cred = BankCsv.parseAmount(_cell(r, _creditCol));
        if (deb != null && deb != 0) {
          amount = -deb.abs();
        } else if (cred != null && cred != 0) {
          amount = cred.abs();
        }
      }
      if (amount == null || amount == 0) continue;
      result.add(ParsedTx(date: date, label: label, amount: amount));
    }
    return result;
  }

  bool get _ready {
    if (_table == null || _dateCol < 0 || _labelCol < 0) return false;
    return _mode == _AmountMode.single
        ? _amountCol >= 0
        : (_debitCol >= 0 && _creditCol >= 0);
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final parsed = _build();

    if (_autoCat) {
      final cats = await ref.read(financeRepositoryProvider).watchCategories().first;
      final byName = {for (final c in cats) c.name.toLowerCase(): c.id};
      for (final p in parsed) {
        final name = Categorizer.guess(p.label);
        if (name != null) p.categoryId = byName[name.toLowerCase()];
      }
    }

    final result = await ref.read(financeRepositoryProvider).importTransactions([
      for (final p in parsed)
        ImportTx(
            date: p.date,
            label: p.label,
            amount: p.amount,
            categoryId: p.categoryId),
    ]);

    if (!mounted) return;
    setState(() => _importing = false);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import terminé'),
        content: Text(
          '${result.added} transaction(s) importée(s).\n'
          '${result.skipped} doublon(s) ignoré(s).',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer un relevé')),
      body: _table == null ? _picker() : _mapper(),
    );
  }

  Widget _picker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Importer un relevé bancaire',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Exporte un fichier CSV depuis ta banque, puis choisis-le ici. '
              'Tu pourras vérifier le mappage des colonnes avant l\'import.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choisir un fichier CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapper() {
    final t = _table!;
    final cols = t.columnCount;
    final preview = _build();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.description_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(_fileName)),
            TextButton(onPressed: _pickFile, child: const Text('Changer')),
          ],
        ),
        Text('${t.rows.length} lignes · séparateur « ${t.delimiter == '\t' ? 'tab' : t.delimiter} »',
            style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 24),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('La 1re ligne est un en-tête'),
          value: _hasHeader,
          onChanged: (v) => setState(() => _hasHeader = v),
        ),
        _colDropdown('Colonne Date', _dateCol, cols,
            (v) => setState(() => _dateCol = v)),
        _colDropdown('Colonne Libellé', _labelCol, cols,
            (v) => setState(() => _labelCol = v)),
        const SizedBox(height: 12),
        SegmentedButton<_AmountMode>(
          segments: const [
            ButtonSegment(value: _AmountMode.single, label: Text('Montant unique')),
            ButtonSegment(
                value: _AmountMode.debitCredit, label: Text('Débit / Crédit')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
        if (_mode == _AmountMode.single)
          _colDropdown('Colonne Montant (signé)', _amountCol, cols,
              (v) => setState(() => _amountCol = v))
        else ...[
          _colDropdown('Colonne Débit', _debitCol, cols,
              (v) => setState(() => _debitCol = v)),
          _colDropdown('Colonne Crédit', _creditCol, cols,
              (v) => setState(() => _creditCol = v)),
        ],
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Catégoriser automatiquement'),
          subtitle: const Text('D\'après le libellé (Carrefour → Alimentation…)'),
          value: _autoCat,
          onChanged: (v) => setState(() => _autoCat = v ?? true),
        ),
        const Divider(height: 24),

        Text('Aperçu (${preview.length} transactions détectées)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (!_ready)
          Text('Sélectionne au moins les colonnes Date, Libellé et Montant.',
              style: TextStyle(color: Theme.of(context).colorScheme.error))
        else if (preview.isEmpty)
          const Text('Aucune ligne exploitable avec ce mappage.')
        else
          ...preview.take(8).map((p) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(Fmt.dayMonth(p.date)),
                trailing: Text(
                  '${p.amount < 0 ? '-' : '+'}${Fmt.euro(p.amount.abs())}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: p.amount < 0
                        ? Theme.of(context).colorScheme.error
                        : Colors.green.shade600,
                  ),
                ),
              )),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (!_ready || preview.isEmpty || _importing) ? null : _import,
          icon: _importing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_done),
          label: Text('Importer ${preview.length} transactions'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _colDropdown(
      String label, int value, int cols, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<int>(
        initialValue: value >= 0 && value < cols ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var i = 0; i < cols; i++)
            DropdownMenuItem(
                value: i,
                child: Text(_colLabel(i), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
