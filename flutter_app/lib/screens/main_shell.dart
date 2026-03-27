import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../l10n/app_localizations.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/expenses')) currentIndex = 1;
    if (location.startsWith('/statistics')) currentIndex = 2;
    if (location.startsWith('/budgets')) currentIndex = 3;
    if (location.startsWith('/settings')) currentIndex = 4;

    return Scaffold(
      body: child,
      // FAB only on home/expenses/statistics/budgets screens
      floatingActionButton: currentIndex != 4
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => context.push('/add-expense'),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_rounded, label: l.home, index: 0, current: currentIndex,
                onTap: (i) => context.go('/home')),
            _NavItem(icon: Icons.list_alt_rounded, label: l.expenses, index: 1, current: currentIndex,
                onTap: (i) => context.go('/expenses')),
            const SizedBox(width: 60),
            _NavItem(icon: Icons.account_balance_wallet_rounded, label: l.budgets, index: 3, current: currentIndex,
                onTap: (i) => context.go('/budgets')),
            _NavItem(icon: Icons.settings_rounded, label: l.settings, index: 4, current: currentIndex,
                onTap: (i) => context.go('/settings')),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondaryLight,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
