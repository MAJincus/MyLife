import 'package:go_router/go_router.dart';

import '../features/agenda/agenda_screen.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/diet/diet_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/health/health_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navShell) => AppShell(navShell: navShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/finance',
            builder: (_, _) => const FinanceScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/health',
            builder: (_, _) => const HealthScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/diet',
            builder: (_, _) => const DietScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/agenda',
            builder: (_, _) => const AgendaScreen(),
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/assistant',
      builder: (_, _) => const AssistantScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
    ),
  ],
);
