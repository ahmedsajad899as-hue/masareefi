import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';

class MarketShell extends StatelessWidget {
  const MarketShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/market/customers')) {
      currentIndex = 1;
    } else if (location.startsWith('/market/products')) {
      currentIndex = 2;
    } else if (location.startsWith('/market/suppliers')) {
      currentIndex = 3;
    } else if (location == '/market/market-settings') {
      currentIndex = 4;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/market/home');
              break;
            case 1:
              context.go('/market/customers');
              break;
            case 2:
              context.go('/market/products');
              break;
            case 3:
              context.go('/market/suppliers');
              break;
            case 4:
              // Navigate to personal expense tracking
              context.go('/home');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'الزبائن',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'الكتالوج',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'الموردين',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'الشخصي',
          ),
        ],
      ),
    );
  }
}
