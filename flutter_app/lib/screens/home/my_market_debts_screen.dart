import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/my_market_debts_provider.dart';

class MyMarketDebtsScreen extends ConsumerStatefulWidget {
  const MyMarketDebtsScreen({super.key});

  @override
  ConsumerState<MyMarketDebtsScreen> createState() =>
      _MyMarketDebtsScreenState();
}

class _MyMarketDebtsScreenState extends ConsumerState<MyMarketDebtsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(myMarketDebtsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myMarketDebtsProvider);
    final fmt = NumberFormat('#,###', 'ar');
    final dateFmt = DateFormat('yyyy/MM/dd', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ديوني من المحلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(myMarketDebtsProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.debts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 72, color: AppColors.success),
                      const SizedBox(height: 12),
                      const Text('لا توجد ديون مستحقة! 🎉',
                          style: TextStyle(
                              fontSize: 16, color: AppColors.success)),
                      const SizedBox(height: 8),
                      Text(
                        'ستظهر هنا الديون التي سجلها أصحاب المحلات على حسابك',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Total banner
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: AppColors.error, size: 32),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إجمالي ديونك',
                                  style: TextStyle(color: AppColors.error)),
                              Text(
                                '${fmt.format(state.totalUnpaid)} د.ع',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () =>
                            ref.read(myMarketDebtsProvider.notifier).load(),
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: state.debts.length,
                          itemBuilder: (_, i) {
                            final market = state.debts[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  child: const Icon(Icons.storefront_rounded,
                                      color: AppColors.primary),
                                ),
                                title: Text(market.storeName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(market.marketOwnerName),
                                trailing: Text(
                                  '${fmt.format(market.totalUnpaid)} د.ع',
                                  style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold),
                                ),
                                children: market.sales.map((sale) {
                                  return ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    leading: const Icon(
                                        Icons.receipt_long_rounded,
                                        size: 18),
                                    title: Text(
                                        '${fmt.format(sale.totalAmount)} د.ع'),
                                    subtitle:
                                        Text(dateFmt.format(sale.saleDate)),
                                    children: [
                                      ...sale.items.map((item) => ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 32),
                                            dense: true,
                                            leading: const Icon(
                                                Icons.circle,
                                                size: 6),
                                            title:
                                                Text(item.productName),
                                            trailing: Text(
                                                '${item.quantity} × ${fmt.format(item.unitPrice)} د.ع'),
                                          )),
                                      if (sale.notes != null &&
                                          sale.notes!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.fromLTRB(
                                                  32, 0, 32, 8),
                                          child: Text(
                                              'ملاحظة: ${sale.notes}',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
