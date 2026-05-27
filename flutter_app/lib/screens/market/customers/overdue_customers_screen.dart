import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/market_customers_provider.dart';

class OverdueCustomersScreen extends ConsumerStatefulWidget {
  const OverdueCustomersScreen({super.key});

  @override
  ConsumerState<OverdueCustomersScreen> createState() =>
      _OverdueCustomersScreenState();
}

class _OverdueCustomersScreenState
    extends ConsumerState<OverdueCustomersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(marketCustomersProvider.notifier).loadOverdue());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketCustomersProvider);
    final fmt = NumberFormat('#,###', 'ar');
    final overdue = state.overdueCustomers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الزبائن المتأخرون'),
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
      ),
      body: overdue.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 64, color: AppColors.success),
                  SizedBox(height: 12),
                  Text('لا يوجد زبائن متأخرون! 🎉',
                      style: TextStyle(color: AppColors.success, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: overdue.length,
              itemBuilder: (_, i) {
                final c = overdue[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                          color: AppColors.error, width: 1)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.error.withValues(alpha: 0.15),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0] : '?',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: c.phone != null ? Text(c.phone!) : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${fmt.format(c.totalDebt)} د.ع',
                          style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold),
                        ),
                        Text('${c.unpaidSalesCount} فاتورة',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    onTap: () =>
                        context.push('/market/customers/${c.id}'),
                  ),
                );
              },
            ),
    );
  }
}
