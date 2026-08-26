import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

/// Une transaction extraite d'un relevé (montant signé : <0 = dépense).
class ParsedTx {
  ParsedTx({
    required this.date,
    required this.label,
    required this.amount,
    this.categoryId,
  });
  final DateTime date;
  final String label;
  final double amount; // signé
  int? categoryId;
}

/// Table CSV brute + métadonnées détectées.
class CsvTable {
  CsvTable({required this.rows, required this.delimiter});
  final List<List<String>> rows;
  final String delimiter;

  int get columnCount =>
      rows.isEmpty ? 0 : rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
}

class BankCsv {
  BankCsv._();

  /// Décode les octets en tentant UTF-8 puis Windows-1252/Latin-1
  /// (encodage fréquent des exports bancaires français).
  static String decodeBytes(Uint8List bytes) {
    try {
      return const Utf8Decoder(allowMalformed: false).convert(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  /// Devine le séparateur parmi ; , et tabulation (le plus régulier gagne).
  static String guessDelimiter(String content) {
    final lines = const LineSplitter()
        .convert(content)
        .where((l) => l.trim().isNotEmpty)
        .take(10)
        .toList();
    if (lines.isEmpty) return ';';
    var best = ';';
    var bestScore = -1;
    for (final d in [';', ',', '\t', '|']) {
      final counts = lines.map((l) => d.allMatches(l).length).toList();
      final total = counts.fold<int>(0, (a, b) => a + b);
      if (total == 0) continue;
      // Régularité : nombre d'occurrences identique d'une ligne à l'autre.
      final first = counts.first;
      final regular = counts.every((c) => c == first) && first > 0;
      final score = total + (regular ? 1000 : 0);
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }

  /// Parse le contenu en lignes de chaînes.
  static CsvTable parse(String content, {String? delimiter}) {
    final delim = delimiter ?? guessDelimiter(content);
    final raw = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
        .convert(content.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
            fieldDelimiter: delim);
    final rows = [
      for (final r in raw)
        [for (final c in r) c.toString().trim()]
    ].where((r) => r.any((c) => c.isNotEmpty)).toList();
    return CsvTable(rows: rows, delimiter: delim);
  }

  /// Convertit un montant FR/EN en double signé. Renvoie null si invalide.
  /// Gère : "1 234,56", "-12.50", "12,00 €", "(30,00)", "1.234,56".
  static double? parseAmount(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    final negative = s.startsWith('(') && s.endsWith(')') || s.contains('-');
    s = s.replaceAll(RegExp(r'[()\s€$£]'), '').replaceAll('+', '');
    s = s.replaceAll(' ', ''); // espace insécable (séparateur de milliers)

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      // Le dernier séparateur est le décimal.
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.'); // 1.234,56
      } else {
        s = s.replaceAll(',', ''); // 1,234.56
      }
    } else if (hasComma) {
      s = s.replaceAll(',', '.'); // décimal virgule
    }
    s = s.replaceAll('-', '');
    final v = double.tryParse(s);
    if (v == null) return null;
    return negative ? -v : v;
  }

  static final _dateFormats = <RegExp>[
    RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$'), // dd/mm/yyyy
    RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2})$'), // dd/mm/yy
  ];

  /// Parse une date FR (jj/mm/aaaa, jj-mm-aa…) ou ISO (aaaa-mm-jj).
  static DateTime? parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // ISO aaaa-mm-jj
    final iso = RegExp(r'^(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})').firstMatch(s);
    if (iso != null) {
      return _safe(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }
    for (final re in _dateFormats) {
      final m = re.firstMatch(s);
      if (m != null) {
        var year = int.parse(m.group(3)!);
        if (year < 100) year += 2000;
        return _safe(year, int.parse(m.group(2)!), int.parse(m.group(1)!));
      }
    }
    return null;
  }

  static DateTime? _safe(int y, int mo, int d) {
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    try {
      return DateTime(y, mo, d);
    } catch (_) {
      return null;
    }
  }

  /// Devine les indices de colonnes à partir des en-têtes.
  static ColumnGuess guessColumns(List<String> headers) {
    int find(List<String> keys) {
      for (var i = 0; i < headers.length; i++) {
        final h = headers[i].toLowerCase();
        if (keys.any((k) => h.contains(k))) return i;
      }
      return -1;
    }

    final date = find(['date']);
    final label =
        find(['libell', 'nature', 'description', 'détail', 'detail', 'motif', 'opération', 'operation']);
    final debit = find(['débit', 'debit']);
    final credit = find(['crédit', 'credit']);
    final amount = find(['montant', 'amount']);
    return ColumnGuess(
      date: date,
      label: label,
      amount: amount,
      debit: debit,
      credit: credit,
    );
  }
}

class ColumnGuess {
  ColumnGuess({
    required this.date,
    required this.label,
    required this.amount,
    required this.debit,
    required this.credit,
  });
  final int date;
  final int label;
  final int amount;
  final int debit;
  final int credit;
}
