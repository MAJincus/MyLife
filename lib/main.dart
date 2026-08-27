import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/notifications.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/security/lock_gate.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'features/widget/home_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  final db = await AppDatabase.open();
  await db.warmup();
  await Notifications.init();

  // Met à jour le widget d'accueil au démarrage et à chaque mise en arrière-plan.
  await HomeWidgetService.update(db);
  WidgetsBinding.instance.addObserver(_WidgetUpdater(db));

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MyLifeApp(),
    ),
  );
}

class _WidgetUpdater extends WidgetsBindingObserver {
  _WidgetUpdater(this.db);
  final AppDatabase db;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      HomeWidgetService.update(db);
    }
  }
}

class MyLifeApp extends StatelessWidget {
  const MyLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyLife',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
    );
  }
}
