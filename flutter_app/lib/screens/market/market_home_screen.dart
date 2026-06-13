import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../models/market_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_customers_provider.dart';
import '../../providers/supplier_invoices_provider.dart';
import '../../services/api_service.dart';
import 'barcode_scanner_screen.dart';

class MarketHomeScreen extends ConsumerStatefulWidget {
  const MarketHomeScreen({super.key});

  @override
  ConsumerState<MarketHomeScreen> createState() => _MarketHomeScreenState();
}

class _MarketHomeScreenState extends ConsumerState<MarketHomeScreen> {
  double _totalReceivable = 0;
  double _totalPayable = 0;
  int _overdueCount = 0;
  bool _loading = true;

  Future<void> _scanBarcode(BuildContext ctx) async {
    final barcode = await Navigator.of(ctx).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    final product = await ApiService.instance.getProductByBarcode(barcode);
    if (!mounted) return;

    if (product != null) {
      context.push('/market/sales/add', extra: {'barcode': barcode, 'product': product});
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('الباركود غير موجود في الكتالوج، يمكنك إضافته الآن'),
          duration: Duration(seconds: 3),
        ),
      );
      context.push('/market/products', extra: {'barcode': barcode});
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiService.instance;

      // Load all unpaid customer sales totals
      final salesData = await api.get(ApiConstants.marketSales, params: {'is_paid': 'false'});
      double recv = 0;
      for (final s in (salesData as List<dynamic>)) {
        recv += (s['total_amount'] as num).toDouble();
      }

      // Load all unpaid supplier invoices
      final supplierData = await api.get(ApiConstants.marketSuppliers, params: {'is_paid': 'false'});
      double pay = 0;
      for (final s in (supplierData as List<dynamic>)) {
        pay += (s['total_amount'] as num).toDouble();
      }

      // Load overdue customers count
      final overdueData = await api.get(ApiConstants.marketCustomersOverdue);
      final overdueCount = (overdueData as List<dynamic>).length;

      if (mounted) {
        setState(() {
          _totalReceivable = recv;
          _totalPayable = pay;
          _overdueCount = overdueCount;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final fmt = NumberFormat('#,###', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.storeName ?? 'لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'مسح باركود',
            onPressed: () => _scanBarcode(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/market/market-settings'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Greeting
                  Text(
                    'أهلاً، ${user?.fullName ?? ''}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'إليك ملخص المحل اليوم',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Stats cards
                  Row(
                    children: [
                      _StatCard(
                        label: 'إجمالي الديون\n(على الزبائن)',
                        value: '${fmt.format(_totalReceivable)} د.ع',
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'مطلوب\n(من الموردين)',
                        value: '${fmt.format(_totalPayable)} د.ع',
                        icon: Icons.local_shipping_rounded,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Overdue alert
                  if (_overdueCount > 0)
                    Card(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.error, width: 1)),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded,
                            color: AppColors.error),
                        title: Text(
                          '$_overdueCount زبون بدين متأخر',
                          style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('اضغط لعرض الزبائن المتأخرين'),
                        onTap: () => context.push('/market/customers/overdue'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: AppColors.error),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Quick actions
                  Text('إجراءات سريعة',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickAction(
                        icon: Icons.person_add_rounded,
                        label: 'إضافة زبون',
                        onTap: () => context.go('/market/customers'),
                      ),
                      _QuickAction(
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'تسجيل دين',
                        onTap: () => context.push('/market/sales/add'),
                      ),
                      _QuickAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'فاتورة مورد',
                        onTap: () => context.push('/market/suppliers/add'),
                      ),
                      _QuickAction(
                        icon: Icons.people_alt_rounded,
                        label: 'كل الزبائن',
                        onTap: () => context.go('/market/customers'),
                      ),
                      _QuickAction(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'مسح باركود',
                        color: AppColors.success,
                        onTap: () => _scanBarcode(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondaryLight)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap,
      this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? AppColors.primary, size: 26),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
