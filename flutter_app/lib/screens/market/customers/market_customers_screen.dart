import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/market_customers_provider.dart';
import '../../../models/market_model.dart';

class MarketCustomersScreen extends ConsumerStatefulWidget {
  const MarketCustomersScreen({super.key});

  @override
  ConsumerState<MarketCustomersScreen> createState() =>
      _MarketCustomersScreenState();
}

class _MarketCustomersScreenState
    extends ConsumerState<MarketCustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(marketCustomersProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة زبون جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  prefixIcon: Icon(Icons.note_rounded)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(marketCustomersProvider.notifier).create(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketCustomersProvider);
    final fmt = NumberFormat('#,###', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('الزبائن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            tooltip: 'الزبائن المتأخرين',
            onPressed: () => context.push('/market/customers/overdue'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث باسم أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(marketCustomersProvider.notifier)
                              .load();
                        })
                    : null,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (q) => ref
                  .read(marketCustomersProvider.notifier)
                  .load(query: q.isEmpty ? null : q),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'live_vision_fab',
            onPressed: () => context.push('/market/live-vision'),
            backgroundColor: Colors.deepPurple,
            tooltip: 'كاميرا مباشرة (لايف)',
            child: const Icon(Icons.videocam_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_customer_fab',
            onPressed: _showAddDialog,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('زبون جديد'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.customers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('لا يوجد زبائن بعد',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(marketCustomersProvider.notifier).load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final c = state.customers[i];
                      return _CustomerTile(
                        customer: c,
                        fmt: fmt,
                        onTap: () =>
                            context.push('/market/customers/${c.id}'),
                        onDelete: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف الزبون'),
                              content: Text('هل تريد حذف ${c.name}؟'),
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
                                .read(marketCustomersProvider.notifier)
                                .delete(c.id);
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.fmt,
    required this.onTap,
    required this.onDelete,
  });

  final MarketCustomerModel customer;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            customer.name.isNotEmpty ? customer.name[0] : '?',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(customer.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: customer.phone != null
            ? Text(customer.phone!,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customer.unpaidSalesCount > 0) ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(customer.totalDebt)} د.ع',
                    style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    '${customer.unpaidSalesCount} فاتورة',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            if (customer.linkedUserId != null)
              const Tooltip(
                message: 'مرتبط بحساب تطبيق',
                child: Icon(Icons.link_rounded,
                    color: AppColors.success, size: 18),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.grey, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
