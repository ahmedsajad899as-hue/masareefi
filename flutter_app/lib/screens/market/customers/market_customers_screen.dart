import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_colors.dart';
import '../../../providers/market_customers_provider.dart';
import '../../../models/market_model.dart';
import '../../../services/api_service.dart';
import '../barcode_scanner_screen.dart';

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

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    final product = await ApiService.instance.getProductByBarcode(barcode);
    if (!mounted) return;

    if (product != null) {
      context.push('/market/sales/add');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯ ÙÙŠ Ø§Ù„ÙƒØªØ§Ù„ÙˆØ¬ØŒ ÙŠÙ…ÙƒÙ†Ùƒ Ø¥Ø¶Ø§ÙØªÙ‡ Ø§Ù„Ø¢Ù†'),
          duration: Duration(seconds: 3),
        ),
      );
      context.push('/market/products', extra: {'barcode': barcode});
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ø¥Ø¶Ø§ÙØ© Ø²Ø¨ÙˆÙ† Ø¬Ø¯ÙŠØ¯'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Ø§Ù„Ø§Ø³Ù…', prefixIcon: Icon(Icons.person_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                  labelText: 'Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ',
                  prefixIcon: Icon(Icons.phone_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                  labelText: 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
                  prefixIcon: Icon(Icons.note_rounded)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Ø¥Ù„ØºØ§Ø¡')),
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
            child: const Text('Ø¥Ø¶Ø§ÙØ©'),
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
        title: const Text('Ø§Ù„Ø²Ø¨Ø§Ø¦Ù†'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Ù…Ø³Ø­ Ø¨Ø§Ø±ÙƒÙˆØ¯',
            onPressed: _scanBarcode,
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            tooltip: 'Ø§Ù„Ø²Ø¨Ø§Ø¦Ù† Ø§Ù„Ù…ØªØ£Ø®Ø±ÙŠÙ†',
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
                hintText: 'Ø¨Ø­Ø« Ø¨Ø§Ø³Ù… Ø£Ùˆ Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ...',
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
            tooltip: 'ÙƒØ§Ù…ÙŠØ±Ø§ Ù…Ø¨Ø§Ø´Ø±Ø© (Ù„Ø§ÙŠÙ)',
            child: const Icon(Icons.videocam_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_customer_fab',
            onPressed: _showAddDialog,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Ø²Ø¨ÙˆÙ† Ø¬Ø¯ÙŠØ¯'),
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
                      Text('Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø²Ø¨Ø§Ø¦Ù† Ø¨Ø¹Ø¯',
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
                              title: const Text('Ø­Ø°Ù Ø§Ù„Ø²Ø¨ÙˆÙ†'),
                              content: Text('Ù‡Ù„ ØªØ±ÙŠØ¯ Ø­Ø°Ù ${c.name}ØŸ'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Ø¥Ù„ØºØ§Ø¡')),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error),
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Ø­Ø°Ù')),
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
                    '${fmt.format(customer.totalDebt)} Ø¯.Ø¹',
                    style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    '${customer.unpaidSalesCount} ÙØ§ØªÙˆØ±Ø©',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            if (customer.linkedUserId != null)
              const Tooltip(
                message: 'Ù…Ø±ØªØ¨Ø· Ø¨Ø­Ø³Ø§Ø¨ ØªØ·Ø¨ÙŠÙ‚',
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
