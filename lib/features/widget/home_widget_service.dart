import 'package:drift/drift.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/format.dart';
import '../../data/database.dart';

/// Calcule les KPI du jour et les pousse vers le widget écran d'accueil.
class HomeWidgetService {
  HomeWidgetService._();

  static Future<void> update(AppDatabase db) async {
    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final meals = await (db.select(db.mealEntries)
            ..where((m) => m.at.isBiggerOrEqualValue(dayStart))
            ..where((m) => m.at.isSmallerThanValue(dayEnd)))
          .get();
      final kcal = meals.fold<double>(0, (s, m) => s + m.kcal).round();

      final waters = await (db.select(db.waterEntries)
            ..where((w) => w.at.isBiggerOrEqualValue(dayStart))
            ..where((w) => w.at.isSmallerThanValue(dayEnd)))
          .get();
      final water = waters.fold<int>(0, (s, w) => s + w.ml);

      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);
      final txs = await (db.select(db.transactions)
            ..where((t) => t.date.isBiggerOrEqualValue(monthStart))
            ..where((t) => t.date.isSmallerThanValue(monthEnd)))
          .get();
      double income = 0, expense = 0;
      for (final t in txs) {
        if (t.kind == 'income') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }

      await HomeWidget.saveWidgetData<String>('calories', '$kcal kcal');
      await HomeWidget.saveWidgetData<String>('water', '$water ml');
      await HomeWidget.saveWidgetData<String>(
          'balance', Fmt.euro(income - expense));
      await HomeWidget.updateWidget(androidName: 'MyLifeWidgetProvider');
    } catch (_) {
      // Widget non installé / plateforme non supportée : on ignore.
    }
  }
}
