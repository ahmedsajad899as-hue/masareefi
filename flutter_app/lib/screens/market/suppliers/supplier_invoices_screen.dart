import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/market_model.dart';
import '../../../providers/supplier_invoices_provider.dart';

class SupplierInvoicesScreen extends ConsumerStatefulWidget {
  const SupplierInvoicesScreen({super.key});

  @override
  ConsumerState<SupplierInvoicesScreen> createState() =>
      _SupplierInvoicesScreenState();
}

class _SupplierInvoicesScreenState
    extends ConsumerState<SupplierInvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(supplierInvoicesProvider.notifier).load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierInvoicesProvider);
    final fmt = NumberFormat('#,###', 'ar');
    final dateFmt = DateFormat('yyyy/MM/dd', 'ar');

    final all = state.invoices;
    final unpaid = all.where((i) => !i.isPaid).toList();
    final paid = all.where((i) => i.isPaid).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير الموردين'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'الكل (${all.length})'),
            Tab(
                child: Text('غير مدفوعة (${unpaid.length})',
                    style: const TextStyle(color: AppColors.error))),
            Tab(
                child: Text('مدفوعة (${paid.length})',
                    style: const TextStyle(color: AppColors.success))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/market/suppliers/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('فاتورة جديدة'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [all, unpaid, paid]
                  .map((list) => _InvoiceList(
                      invoices: list, fmt: fmt, dateFmt: dateFmt))
                  .toList(),
            ),
    );
  }
}

class _InvoiceList extends ConsumerWidget {
  const _InvoiceList(
      {required this.invoices, required this.fmt, required this.dateFmt});

  final List<SupplierInvoiceModel> invoices;
  final NumberFormat fmt;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invoices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا توجد فواتير', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(supplierInvoicesProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: invoices.length,
        itemBuilder: (_, i) {
          final inv = invoices[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: inv.isPaid
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.warning.withValues(alpha: 0.4))),
            child: ExpansionTile(
              leading: Icon(
                inv.isPaid
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                color: inv.isPaid ? AppColors.success : AppColors.warning,
              ),
              title: Text(inv.supplierName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(dateFmt.format(inv.invoiceDate)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt.format(inv.totalAmount)} د.ع',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: inv.isPaid
                              ? AppColors.success
                              : AppColors.warning)),
                  if (inv.dueDate != null)
                    Text('استحقاق: ${dateFmt.format(inv.dueDate!)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
              children: [
                // Items
                ...inv.items.map((item) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.circle, size: 6),
                      title: Text(item.productName),
                      trailing: Text(
                          '${item.quantity} × ${fmt.format(item.unitPrice)} = ${fmt.format(item.lineTotal)} د.ع'),
                    )),
                if (inv.notes != null && inv.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('ملاحظة: ${inv.notes}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                // Actions
                if (!inv.isPaid)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('تسديد'),
                          onPressed: () => ref
                              .read(supplierInvoicesProvider.notifier)
                              .markPaid(inv.id),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error)),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16),
                          label: const Text('حذف'),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('حذف الفاتورة'),
                                content: const Text(
                                    'هل تريد حذف هذه الفاتورة؟'),
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
                                  .read(supplierInvoicesProvider.notifier)
                                  .delete(inv.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
