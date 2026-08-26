import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/database.dart';

final patrimoineRepositoryProvider = Provider<PatrimoineRepository>((ref) {
  return PatrimoineRepository(ref.watch(databaseProvider));
});

class PatrimoineRepository {
  PatrimoineRepository(this.db);
  final AppDatabase db;

  Stream<List<Account>> watchAccounts() {
    return (db.select(db.accounts)
          ..where((a) => a.archived.equals(false))
          ..orderBy([(a) => OrderingTerm(expression: a.name)]))
        .watch();
  }

  /// Patrimoine net = somme des actifs − somme des passifs.
  Stream<double> watchNetWorth() {
    return watchAccounts().map(_netWorth);
  }

  static double _netWorth(List<Account> accounts) {
    double v = 0;
    for (final a in accounts) {
      v += a.kind == 'liability' ? -a.balance : a.balance;
    }
    return v;
  }

  /// Total des comptes liquides (pour la prévision de trésorerie).
  Future<double> liquidTotal() async {
    final accounts = await watchAccounts().first;
    return accounts
        .where((a) => a.kind == 'asset' && a.liquid)
        .fold<double>(0, (s, a) => s + a.balance);
  }

  Stream<List<NetWorthPoint>> watchNetWorthPoints() {
    return (db.select(db.netWorthPoints)
          ..orderBy([(p) => OrderingTerm(expression: p.date)]))
        .watch();
  }

  Future<void> addAccount(AccountsCompanion a) async {
    await db.into(db.accounts).insert(a);
    await _snapshot();
  }

  Future<void> updateAccount(int id, AccountsCompanion patch) async {
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(patch);
    await _snapshot();
  }

  Future<void> archiveAccount(int id) async {
    await (db.update(db.accounts)..where((a) => a.id.equals(id)))
        .write(const AccountsCompanion(archived: Value(true)));
    await _snapshot();
  }

  /// Enregistre un point d'historique du patrimoine pour aujourd'hui
  /// (un seul point par jour).
  Future<void> _snapshot() async {
    final accounts = await watchAccounts().first;
    final nw = _netWorth(accounts);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    await (db.delete(db.netWorthPoints)
          ..where((p) => p.date.isBetweenValues(start, end)))
        .go();
    await db.into(db.netWorthPoints).insert(
          NetWorthPointsCompanion.insert(date: now, amount: nw),
        );
  }
}
