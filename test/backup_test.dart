import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/core/security/crypto_box.dart';
import 'package:mylife/data/database.dart';
import 'package:mylife/features/backup/backup_service.dart';
import 'package:mylife/features/finance/finance_repository.dart';

void main() {
  group('CryptoBox', () {
    test('chiffre puis déchiffre le même texte', () {
      final enc = CryptoBox.encryptString('coucou secret', 'monMotDePasse');
      final dec = CryptoBox.decryptToString(enc, 'monMotDePasse');
      expect(dec, 'coucou secret');
    });

    test('rejette une mauvaise passphrase', () {
      final enc = CryptoBox.encryptString('data', 'bonne');
      expect(() => CryptoBox.decryptToString(enc, 'mauvaise'),
          throwsA(isA<CryptoException>()));
    });
  });

  test('sauvegarde puis restauration recrée les données', () async {
    // Base source avec des données.
    final source = AppDatabase(NativeDatabase.memory());
    final repo = FinanceRepository(source);
    await repo.addTransaction(TransactionsCompanion.insert(
      amount: 42.5,
      kind: const Value('expense'),
      date: DateTime(2026, 8, 20),
      note: const Value('Test resto'),
    ));
    await repo.addGoal(SavingsGoalsCompanion.insert(
        name: 'Vacances', targetAmount: const Value(1500)));

    final bytes = await BackupService(source).export('phrase-secrete');
    await source.close();

    // Base cible vierge → import.
    final target = AppDatabase(NativeDatabase.memory());
    await BackupService(target).import(bytes, 'phrase-secrete');

    final txs = await FinanceRepository(target).watchTransactions().first;
    final goals = await FinanceRepository(target).watchGoals().first;
    expect(txs.length, 1);
    expect(txs.single.amount, 42.5);
    expect(txs.single.note, 'Test resto');
    expect(goals.single.name, 'Vacances');

    await target.close();
  });
}
