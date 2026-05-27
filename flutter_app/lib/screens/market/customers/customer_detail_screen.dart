import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/market_model.dart';
import '../../../providers/market_customers_provider.dart';
import '../../../providers/market_sales_provider.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  MarketCustomerModel? _customer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomer();
      ref
          .read(marketSalesProvider.notifier)
          .loadForCustomer(widget.customerId);
    });
  }

  void _loadCustomer() {
    final customers = ref.read(marketCustomersProvider).customers;
    final found = customers.cast<MarketCustomerModel?>().firstWhere(
          (c) => c?.id == widget.customerId,
          orElse: () => null,
        );
    if (found != null && mounted) setState(() => _customer = found);
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(marketSalesProvider);
    final fmt = NumberFormat('#,###', 'ar');
    final dateFmt = DateFormat('yyyy/MM/dd', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? 'تفاصيل الزبون'),
        actions: [
          if (_customer?.linkedUserId != null)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Tooltip(
                message: 'مرتبط بحساب تطبيق',
                child: Icon(Icons.link_rounded, color: AppColors.success),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/market/sales/add', extra: {'customerId': widget.customerId}),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('إضافة دين'),
      ),
      body: salesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Customer summary card
                if (_customer != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                _customer!.name.isNotEmpty
                                    ? _customer!.name[0]
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 22,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_customer!.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  if (_customer!.phone != null) ...[
                                    const SizedBox(height: 2),
                                    Text(_customer!.phone!,
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.grey)),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${fmt.format(_customer!.totalDebt)} د.ع',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_customer!.unpaidSalesCount} فاتورة غير مدفوعة',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Sales list
                Expanded(
                  child: salesState.sales.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 56, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('لا توجد فواتير بعد',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                          itemCount: salesState.sales.length,
                          itemBuilder: (_, i) {
                            final sale = salesState.sales[i];
                            return _SaleTile(
                              sale: sale,
                              fmt: fmt,
                              dateFmt: dateFmt,
                              onMarkPaid: sale.isPaid
                                  ? null
                                  : () async {
                                      await ref
                                          .read(marketSalesProvider.notifier)
                                          .markPaid(sale.id);
                                      // Refresh customer info
                                      await ref
                                          .read(marketCustomersProvider.notifier)
                                          .load();
                                      _loadCustomer();
                                    },
                              onDelete: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('حذف الفاتورة'),
                                    content:
                                        const Text('هل تريد حذف هذه الفاتورة؟'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('إلغاء')),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('حذف')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ref
                                      .read(marketSalesProvider.notifier)
                                      .delete(sale.id);
                                  await ref
                                      .read(marketCustomersProvider.notifier)
                                      .load();
                                  _loadCustomer();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.fmt,
    required this.dateFmt,
    required this.onMarkPaid,
    required this.onDelete,
  });

  final MarketSaleModel sale;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final VoidCallback? onMarkPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: sale.isPaid
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3))),
      child: ExpansionTile(
        leading: Icon(
          sale.isPaid
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: sale.isPaid ? AppColors.success : AppColors.error,
        ),
        title: Text(
          '${fmt.format(sale.totalAmount)} د.ع',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: sale.isPaid ? AppColors.success : AppColors.error),
        ),
        subtitle: Text(dateFmt.format(sale.saleDate)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (sale.isPaid ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sale.isPaid ? 'مدفوع' : 'غير مدفوع',
                style: TextStyle(
                    fontSize: 11,
                    color: sale.isPaid ? AppColors.success : AppColors.error),
              ),
            ),
          ],
        ),
        children: [
          // Items list
          ...sale.items.map((item) => ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 6),
                title: Text(item.productName),
                trailing: Text(
                    '${item.quantity} × ${fmt.format(item.unitPrice)} = ${fmt.format(item.lineTotal)} د.ع'),
              )),
          if (sale.notes != null && sale.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('ملاحظة: ${sale.notes}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onMarkPaid != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('تسديد'),
                    onPressed: onMarkPaid,
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('حذف'),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
