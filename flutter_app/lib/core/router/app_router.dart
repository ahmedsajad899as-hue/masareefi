import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/my_market_debts_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/expenses/add_expense_screen.dart';
import '../../screens/statistics/statistics_screen.dart';
import '../../screens/budgets/budgets_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/admin/admin_users_screen.dart';
import '../../screens/market/market_shell.dart';
import '../../screens/market/market_home_screen.dart';
import '../../screens/market/market_settings_screen.dart';
import '../../screens/market/customers/market_customers_screen.dart';
import '../../screens/market/customers/customer_detail_screen.dart';
import '../../screens/market/customers/overdue_customers_screen.dart';
import '../../screens/market/sales/add_sale_screen.dart';
import '../../screens/market/sales/vision_sale_screen.dart';
import '../../screens/market/sales/live_vision_sale_screen.dart';
import '../../screens/market/suppliers/supplier_invoices_screen.dart';
import '../../screens/market/suppliers/add_supplier_invoice_screen.dart';
import '../../screens/market/products/market_products_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  final isMarketOwner = authState.user?.isMarketOwner == true;
  final initialLocation = authState.isAuthenticated
      ? (isMarketOwner ? '/market/home' : '/home')
      : '/login';

  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) {
        return auth.user?.isMarketOwner == true ? '/market/home' : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // ── Regular user shell ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
          GoRoute(
              path: '/statistics',
              builder: (_, __) => const StatisticsScreen()),
          GoRoute(path: '/budgets', builder: (_, __) => const BudgetsScreen()),
          GoRoute(
              path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),

      // ── Market owner shell ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MarketShell(child: child),
        routes: [
          GoRoute(
              path: '/market/home',
              builder: (_, __) => const MarketHomeScreen()),
          GoRoute(
              path: '/market/customers',
              builder: (_, __) => const MarketCustomersScreen()),
          GoRoute(
              path: '/market/customers/overdue',
              builder: (_, __) => const OverdueCustomersScreen()),
          GoRoute(
            path: '/market/customers/:id',
            builder: (_, state) =>
                CustomerDetailScreen(customerId: state.pathParameters['id']!),
          ),
          GoRoute(
              path: '/market/suppliers',
              builder: (_, __) => const SupplierInvoicesScreen()),
          GoRoute(
              path: '/market/market-settings',
              builder: (_, __) => const MarketSettingsScreen()),
          GoRoute(
              path: '/market/products',
              builder: (_, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return MarketProductsScreen(
                    initialBarcode: extra?['barcode'] as String?);
              }),
        ],
      ),

      // ── Market full-screen routes (no shell) ────────────────────────
      GoRoute(
        path: '/market/sales/add',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddSaleScreen(
              preselectedCustomerId: extra?['customerId'] as String?);
        },
      ),
      GoRoute(
        path: '/market/suppliers/add',
        builder: (_, __) => const AddSupplierInvoiceScreen(),
      ),
      GoRoute(
        path: '/market/vision-sale/:customerId',
        builder: (_, state) => VisionSaleScreen(
            customerId: state.pathParameters['customerId']!),
      ),
      GoRoute(
        path: '/market/live-vision',
        builder: (_, __) => const LiveVisionSaleScreen(),
      ),
      GoRoute(
        path: '/market/live-vision-sale/:customerId',
        builder: (_, state) => LiveVisionSaleScreen(
            customerId: state.pathParameters['customerId']!),
      ),

      // ── Regular routes (no shell) ───────────────────────────────────
      GoRoute(
        path: '/add-expense',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddExpenseScreen(initialData: extra);
        },
      ),
      GoRoute(
        path: '/my-debts',
        builder: (_, __) => const MyMarketDebtsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const AdminUsersScreen(),
      ),
    ],
  );
});
