import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/expense_model.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/settings_provider.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(expensesProvider.notifier).load());
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteConfirm),
        content: Text(l.deleteWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(expensesProvider.notifier).remove(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.expenseDeleted), backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(expensesProvider);
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final currency = settings.currency;
    final fmt = NumberFormat('#,##0', 'en');

    return Scaffold(
      appBar: AppBar(title: Text(l.expenses)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(expensesProvider.notifier).load(),
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : state.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 72, color: AppColors.textSecondaryLight),
                        const SizedBox(height: 16),
                        Text(l.noExpensesYet, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final exp = state.items[i];
                      return _SwipeableExpenseCard(
                        expense: exp,
                        lang: lang,
                        currency: currency,
                        fmt: fmt,
                        onEdit: () => context.push('/add-expense', extra: {
                          'expense_id': exp.id,
                          'amount': exp.amount,
                          'description': exp.description,
                          'category_id': exp.categoryId,
                          'expense_date': exp.expenseDate.toIso8601String(),
                          'note': exp.note,
                        }),
                        onDelete: () => _confirmDelete(context, l, exp.id),
                      );
                    },
                  ),
      ),
    );
  }
}

class _SwipeableExpenseCard extends StatelessWidget {
  const _SwipeableExpenseCard({
    required this.expense,
    required this.lang,
    required this.currency,
    required this.fmt,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseModel expense;
  final String lang;
  final String currency;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cat = expense.category;
    final color = cat != null
        ? Color(int.parse(cat.color.replaceFirst('#', 'FF'), radix: 16))
        : AppColors.other;

    return Dismissible(
      key: ValueKey(expense.id),
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.edit_rounded, color: AppColors.primary),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      onDismissed: (dir) {
        if (dir == DismissDirection.startToEnd) {
          onEdit();
        } else {
          onDelete();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(cat?.icon ?? '💰', style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description?.isNotEmpty == true
                        ? expense.description!
                        : (cat?.localName(lang) ?? '—'),
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(cat?.localName(lang) ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(expense.expenseDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${fmt.format(expense.amount)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
