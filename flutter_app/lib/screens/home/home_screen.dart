import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stats_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(statsProvider.notifier).loadDashboard();
      ref.read(expensesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user;
    final stats = ref.watch(statsProvider);
    final expenses = ref.watch(expensesProvider);
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final currency = settings.currency;
    final now = DateTime.now();
    final fmt = NumberFormat('#,##0', 'en');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(statsProvider.notifier).loadDashboard();
          await ref.read(expensesProvider.notifier).load();
        },
        child: CustomScrollView(
          slivers: [
            // ─── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l.greeting()}، ${user?.fullName.split(' ').first ?? ''}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'Cairo',
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEEE، d MMMM', lang == 'ar' ? 'ar' : 'en').format(now),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white24,
                                child: Text(
                                  user?.fullName.isNotEmpty == true
                                      ? user!.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            l.totalSpent,
                            style: const TextStyle(
                                color: Colors.white70, fontFamily: 'Cairo', fontSize: 13),
                          ),
                          Text(
                            '${fmt.format(stats.monthly?['total'] ?? 0)} $currency',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Daily Card ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _DailySummaryCard(
                  l: l,
                  daily: stats.daily,
                  currency: currency,
                  fmt: fmt,
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
              ),
            ),

            // ─── Recent Expenses ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.recentExpenses,
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: () => context.go('/expenses'),
                      child: Text(l.viewAll,
                          style: const TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),

            if (expenses.isLoading && expenses.items.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                    child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )),
              )
            else if (expenses.items.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(l: l),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final expense = expenses.items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: _ExpenseCard(
                        expense: expense,
                        lang: lang,
                        currency: currency,
                        fmt: fmt,
                      ).animate().fadeIn(delay: Duration(milliseconds: i * 60)).slideX(begin: 0.05),
                    );
                  },
                  childCount: expenses.items.take(10).length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({
    required this.l,
    required this.daily,
    required this.currency,
    required this.fmt,
  });

  final AppLocalizations l;
  final Map<String, dynamic>? daily;
  final String currency;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final total = (daily?['total'] as num?)?.toDouble() ?? 0;
    final count = (daily?['count'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.today_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.dailySummary, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '${fmt.format(total)} $currency',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Text('$count', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(l.expenses, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.lang,
    required this.currency,
    required this.fmt,
  });

  final ExpenseModel expense;
  final String lang;
  final String currency;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final cat = expense.category;
    final color = cat != null
        ? Color(int.parse(cat.color.replaceFirst('#', 'FF'), radix: 16))
        : AppColors.other;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                cat?.icon ?? '💰',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description?.isNotEmpty == true
                      ? expense.description!
                      : (cat?.localName(lang) ?? ''),
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  cat?.localName(lang) ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
          Text(
            '${fmt.format(expense.amount)} ${expense.currency}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_rounded,
                size: 80, color: AppColors.textSecondaryLight),
            const SizedBox(height: 16),
            Text(l.noExpensesYet,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.startTracking,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
