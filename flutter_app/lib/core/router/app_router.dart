import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/expenses/add_expense_screen.dart';
import '../../screens/statistics/statistics_screen.dart';
import '../../screens/budgets/budgets_screen.dart';
import '../../screens/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/home' : '/login',
    redirect: (context, state) {
      final isAuth = ref.read(authProvider).isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
          GoRoute(path: '/statistics', builder: (_, __) => const StatisticsScreen()),
          GoRoute(path: '/budgets', builder: (_, __) => const BudgetsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/add-expense',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddExpenseScreen(initialData: extra);
        },
      ),
    ],
  );
});
