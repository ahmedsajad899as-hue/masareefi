import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_colors.dart';
import '../../../providers/supplier_invoices_provider.dart';

class AddSupplierInvoiceScreen extends ConsumerStatefulWidget {
  const AddSupplierInvoiceScreen({super.key});

  @override
  ConsumerState<AddSupplierInvoiceScreen> createState() =>
      _AddSupplierInvoiceScreenState();
}

class _AddSupplierInvoiceScreenState
    extends ConsumerState<AddSupplierInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  final List<_ItemRow> _items = [_ItemRow()];
  bool _saving = false;

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  double get _total => _items.fold(0.0, (s, r) {
        final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
        final price = double.tryParse(r.priceCtrl.text) ?? 0;
        return s + qty * price;
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final items = _items.map((r) => {
          'product_name': r.nameCtrl.text.trim(),
          'quantity': double.tryParse(r.qtyCtrl.text) ?? 1,
          'unit_price': double.tryParse(r.priceCtrl.text) ?? 0,
        }).toList();

    final inv = await ref.read(supplierInvoicesProvider.notifier).create(
          supplierName: _supplierCtrl.text.trim(),
          invoiceDate: _invoiceDate,
          dueDate: _dueDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          items: items,
        );

    setState(() => _saving = false);

    if (inv != null && mounted) {
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø­ÙØ¸'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'ar');
    final dateFmt = DateFormat('yyyy/MM/dd', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ÙØ§ØªÙˆØ±Ø© Ù…ÙˆØ±Ø¯ Ø¬Ø¯ÙŠØ¯Ø©'),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _submit,
              child: const Text('Ø­ÙØ¸',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Supplier name
                  TextFormField(
                    controller: _supplierCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ø§Ø³Ù… Ø§Ù„Ù…ÙˆØ±Ø¯ / Ø§Ù„Ø´Ø±ÙƒØ©',
                      prefixIcon: Icon(Icons.local_shipping_rounded),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Ù…Ø·Ù„ÙˆØ¨' : null,
                  ),
                  const SizedBox(height: 16),

                  // Invoice date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary),
                    title: const Text('ØªØ§Ø±ÙŠØ® Ø§Ù„ÙØ§ØªÙˆØ±Ø©'),
                    subtitle: Text(dateFmt.format(_invoiceDate)),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (p != null) setState(() => _invoiceDate = p);
                    },
                  ),

                  // Due date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded,
                        color: AppColors.warning),
                    title: const Text('ØªØ§Ø±ÙŠØ® Ø§Ù„Ø§Ø³ØªØ­Ù‚Ø§Ù‚ (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)'),
                    subtitle: Text(
                        _dueDate != null ? dateFmt.format(_dueDate!) : 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯'),
                    trailing: _dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _dueDate = null),
                          )
                        : const Icon(Icons.edit_calendar_rounded),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate:
                            _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                      );
                      if (p != null) setState(() => _dueDate = p);
                    },
                  ),

                  const Divider(),

                  // Items header
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Ø§Ù„Ù…ÙˆØ§Ø¯',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold))),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ø¥Ø¶Ø§ÙØ© Ù…Ø§Ø¯Ø©'),
                        onPressed: () =>
                            setState(() => _items.add(_ItemRow())),
                      ),
                    ],
                  ),

                  // Items
                  ...List.generate(_items.length, (i) {
                    final row = _items[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('${i + 1}.',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const Spacer(),
                                if (_items.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: AppColors.error),
                                    onPressed: () =>
                                        setState(() => _items.removeAt(i)),
                                  ),
                              ],
                            ),
                            TextFormField(
                              controller: row.nameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Ø§Ø³Ù… Ø§Ù„Ù…Ø§Ø¯Ø©',
                                  prefixIcon:
                                      Icon(Icons.inventory_2_rounded)),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Ù…Ø·Ù„ÙˆØ¨'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: row.qtyCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                        labelText: 'Ø§Ù„ÙƒÙ…ÙŠØ©'),
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Ù…Ø·Ù„ÙˆØ¨';
                                      if (double.tryParse(v) == null)
                                        return 'Ø±Ù‚Ù… ØºÙŠØ± ØµØ­ÙŠØ­';
                                      return null;
                                    },
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: row.priceCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                        labelText: 'Ø§Ù„Ø³Ø¹Ø± (Ø¯.Ø¹)'),
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Ù…Ø·Ù„ÙˆØ¨';
                                      if (double.tryParse(v) == null)
                                        return 'Ø±Ù‚Ù… ØºÙŠØ± ØµØ­ÙŠØ­';
                                      return null;
                                    },
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  // Total
                  Card(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            '${fmt.format(_total)} Ø¯.Ø¹',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Notes
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
                      prefixIcon: Icon(Icons.note_rounded),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Ø­ÙØ¸ Ø§Ù„ÙØ§ØªÙˆØ±Ø©'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(14)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ItemRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
