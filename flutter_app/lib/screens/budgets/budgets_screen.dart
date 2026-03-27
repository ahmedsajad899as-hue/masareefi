import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/stats_model.dart';
import '../../providers/budgets_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/settings_provider.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final budgets = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.budgets),
        centerTitle: true,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: l.isArabic ? 'الميزانيات' : 'Budgets'),
            Tab(text: l.isArabic ? 'الأهداف' : 'Goals'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _tab.index == 0
                ? _showAddBudgetDialog(context)
                : _showAddGoalDialog(context),
          ),
        ],
      ),
      body: budgets.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tab,
              children: [
                _BudgetsTab(l: l, budgets: budgets.budgets),
                _GoalsTab(l: l, goals: budgets.goals),
              ],
            ),
    );
  }

  Future<void> _showAddBudgetDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final categoriesAsync = ref.read(categoriesProvider);
    final lang = ref.read(settingsProvider).language;
    final cats = categoriesAsync.value ?? [];

    String? categoryId;
    final amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.isArabic ? 'إضافة ميزانية' : 'Add Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l.category),
              items: cats.map((cat) => DropdownMenuItem(
                value: cat.id,
                child: Row(
                  children: [
                    Text(cat.icon),
                    const SizedBox(width: 8),
                    Text(cat.localName(lang)),
                  ],
                ),
              )).toList(),
              onChanged: (v) => categoryId = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.amount),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (categoryId == null || amountCtrl.text.isEmpty) return;
              final now = DateTime.now();
              await ref.read(budgetsProvider.notifier).createBudget({
                'category_id': categoryId,
                'amount': double.parse(amountCtrl.text),
                'year': now.year,
                'month': now.month,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddGoalDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    DateTime? deadline;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(l.isArabic ? 'إضافة هدف' : 'Add Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: l.isArabic ? 'عنوان الهدف' : 'Goal Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.isArabic ? 'المبلغ المستهدف' : 'Target Amount'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  setDlgState(() => deadline = picked);
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(deadline == null
                    ? (l.isArabic ? 'تحديد الموعد النهائي' : 'Set Deadline')
                    : '${deadline!.day}/${deadline!.month}/${deadline!.year}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.isArabic ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || targetCtrl.text.isEmpty) return;
                await ref.read(budgetsProvider.notifier).createGoal({
                  'title': titleCtrl.text.trim(),
                  'target_amount': double.parse(targetCtrl.text),
                  if (deadline != null) 'deadline': deadline!.toIso8601String().split('T').first,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Budgets Tab ──────────────────────────────────────────────────────────────

class _BudgetsTab extends ConsumerWidget {
  const _BudgetsTab({required this.l, required this.budgets});
  final AppLocalizations l;
  final List<BudgetModel> budgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(settingsProvider).currency;
    final lang = ref.watch(settingsProvider).language;

    if (budgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.textSecondaryLight),
            const SizedBox(height: 12),
            Text(l.isArabic ? 'لا توجد ميزانيات' : 'No budgets yet', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(budgetsProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: budgets.length,
        itemBuilder: (_, i) {
          final b = budgets[i];
          final pct = b.amount > 0 ? (b.spent / b.amount).clamp(0.0, 1.0) : 0.0;
          final isOver = pct >= 1.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(b.category?.icon ?? '💰', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang == 'ar' ? (b.category?.nameAr ?? '') : (b.category?.nameEn ?? ''),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                        onPressed: () => ref.read(budgetsProvider.notifier).deleteBudget(b.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: AppColors.textSecondaryLight.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(isOver ? AppColors.error : AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${b.spent.toStringAsFixed(0)} / ${b.amount.toStringAsFixed(0)} $currency',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isOver ? AppColors.error : AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  if (isOver)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l.isArabic ? '⚠️ تجاوزت الميزانية' : '⚠️ Budget exceeded',
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                ],
              ).animate().fadeIn(),
            ),
          );
        },
      ),
    );
  }
}

// ─── Goals Tab ────────────────────────────────────────────────────────────────

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab({required this.l, required this.goals});
  final AppLocalizations l;
  final List<GoalModel> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(settingsProvider).currency;

    if (goals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_outlined, size: 64, color: AppColors.textSecondaryLight),
            const SizedBox(height: 12),
            Text(l.isArabic ? 'لا توجد أهداف' : 'No goals yet', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(budgetsProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: goals.length,
        itemBuilder: (_, i) {
          final g = goals[i];
          final pct = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: g.isAchieved ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          g.isAchieved ? Icons.emoji_events_rounded : Icons.flag_rounded,
                          color: g.isAchieved ? AppColors.success : AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.title, style: Theme.of(context).textTheme.titleSmall),
                            if (g.deadline != null)
                              Text(
                                '${l.isArabic ? 'الموعد:' : 'Due:'} ${g.deadline!.split('T').first}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                        onPressed: () => ref.read(budgetsProvider.notifier).deleteGoal(g.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 10,
                          backgroundColor: AppColors.textSecondaryLight.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation(g.isAchieved ? AppColors.success : AppColors.primary),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '${g.currentAmount.toStringAsFixed(0)} / ${g.targetAmount.toStringAsFixed(0)} $currency',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!g.isAchieved)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showAddFundsDialog(context, ref, g),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l.isArabic ? 'إضافة مبلغ' : 'Add Funds'),
                      ),
                    ),
                ],
              ).animate().fadeIn(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddFundsDialog(BuildContext context, WidgetRef ref, GoalModel goal) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.isArabic ? 'إضافة مبلغ للهدف' : 'Add Funds to Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.amount),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(ctrl.text);
              if (amt == null) return;
              final newAmt = goal.currentAmount + amt;
              await ref.read(budgetsProvider.notifier).updateGoal(goal.id, {
                'current_amount': newAmt,
                if (newAmt >= goal.targetAmount) 'is_achieved': true,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
