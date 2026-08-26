import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/data/database.dart';
import 'package:mylife/features/finance/finance_repository.dart';
import 'package:mylife/features/finance/import/bank_csv.dart';
import 'package:mylife/features/finance/import/categorizer.dart';

void main() {
  group('parseAmount (formats FR/EN)', () {
    test('virgule décimale', () => expect(BankCsv.parseAmount('12,50'), 12.5));
    test('négatif', () => expect(BankCsv.parseAmount('-12,50'), -12.5));
    test('point décimal', () => expect(BankCsv.parseAmount('12.00'), 12.0));
    test('milliers espace + virgule',
        () => expect(BankCsv.parseAmount('1 234,56'), 1234.56));
    test('milliers point + virgule',
        () => expect(BankCsv.parseAmount('1.234,56'), 1234.56));
    test('milliers virgule + point',
        () => expect(BankCsv.parseAmount('1,234.56'), 1234.56));
    test('parenthèses = négatif',
        () => expect(BankCsv.parseAmount('(30,00)'), -30.0));
    test('symbole €', () => expect(BankCsv.parseAmount('12,00 €'), 12.0));
    test('vide → null', () => expect(BankCsv.parseAmount('  '), isNull));
  });

  group('parseDate', () {
    test('jj/mm/aaaa',
        () => expect(BankCsv.parseDate('25/08/2026'), DateTime(2026, 8, 25)));
    test('iso aaaa-mm-jj',
        () => expect(BankCsv.parseDate('2026-08-25'), DateTime(2026, 8, 25)));
    test('jj-mm-aa (2 chiffres)',
        () => expect(BankCsv.parseDate('25-08-26'), DateTime(2026, 8, 25)));
    test('invalide → null', () => expect(BankCsv.parseDate('bonjour'), isNull));
    test('mois invalide → null',
        () => expect(BankCsv.parseDate('25/13/2026'), isNull));
  });

  test('guessDelimiter détecte le point-virgule', () {
    const csv = 'Date;Libelle;Montant\n25/08/2026;CARREFOUR;-12,50';
    expect(BankCsv.guessDelimiter(csv), ';');
  });

  test('parse + guessColumns sur un relevé FR type', () {
    const content =
        'Date;Libelle;Debit;Credit\n25/08/2026;CARREFOUR MARKET;12,50;\n'
        '26/08/2026;VIREMENT SALAIRE;;2000,00';
    final table = BankCsv.parse(content);
    expect(table.rows.length, 3);
    final g = BankCsv.guessColumns(table.rows.first);
    expect(g.date, 0);
    expect(g.label, 1);
    expect(g.debit, 2);
    expect(g.credit, 3);
  });

  test('catégoriseur reconnaît les marchands', () {
    expect(Categorizer.guess('PAIEMENT CARREFOUR MARKET'), 'Alimentation');
    expect(Categorizer.guess('SNCF CONNECT'), 'Transport');
    expect(Categorizer.guess('NETFLIX.COM'), 'Abonnements');
    expect(Categorizer.guess('PHARMACIE DU CENTRE'), 'Santé');
    expect(Categorizer.guess('libellé inconnu xyz'), isNull);
  });

  test('import dédoublonne les transactions identiques', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = FinanceRepository(db);
    final items = [
      ImportTx(date: DateTime(2026, 8, 25), label: 'CARREFOUR', amount: -12.5),
      ImportTx(date: DateTime(2026, 8, 26), label: 'SALAIRE', amount: 2000),
    ];

    final r1 = await repo.importTransactions(items);
    expect(r1.added, 2);
    expect(r1.skipped, 0);

    // Réimport du même relevé → tout ignoré.
    final r2 = await repo.importTransactions(items);
    expect(r2.added, 0);
    expect(r2.skipped, 2);

    final txs = await repo.watchTransactions().first;
    expect(txs.length, 2);
    // Le crédit devient un revenu, le débit une dépense.
    expect(txs.where((t) => t.kind == 'income').length, 1);
    expect(txs.where((t) => t.kind == 'expense').length, 1);

    await db.close();
  });
}
