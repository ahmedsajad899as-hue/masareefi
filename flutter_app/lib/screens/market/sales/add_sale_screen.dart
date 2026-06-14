import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/market_model.dart';
import '../../../providers/market_customers_provider.dart';
import '../../../providers/market_sales_provider.dart';
import '../continuous_barcode_scanner_screen.dart';

class AddSaleScreen extends ConsumerStatefulWidget {
  const AddSaleScreen({super.key, this.preselectedCustomerId});
  final String? preselectedCustomerId;

  @override
  ConsumerState<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends ConsumerState<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  DateTime _saleDate = DateTime.now();
  String? _selectedCustomerId;
  final List<_ItemRow> _items = [_ItemRow()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.preselectedCustomerId;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(marketCustomersProvider.notifier).load());
  }

  @override
  void dispose() {
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

  Future<void> _scanBarcode() async {
    final found = await Navigator.of(context).push<List<dynamic>>(
      MaterialPageRoute(
          builder: (_) => const ContinuousBarcodeScannerScreen()),
    );
    if (found == null || found.isEmpty || !mounted) return;

    setState(() {
      for (final product in found.cast<MarketProductModel>()) {
        final row = _ItemRow();
        row.nameCtrl.text = product.name;
        row.priceCtrl.text = product.unitPrice.toString();
        row.qtyCtrl.text = '1';
        _items.add(row);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${found.length} منتج'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى اختيار الزبون')));
      return;
    }
    setState(() => _saving = true);

    final items = _items.map((r) => {
          'product_name': r.nameCtrl.text.trim(),
          'quantity': double.tryParse(r.qtyCtrl.text) ?? 1,
          'unit_price': double.tryParse(r.priceCtrl.text) ?? 0,
        }).toList();

    final sale = await ref.read(marketSalesProvider.notifier).createSale(
          customerId: _selectedCustomerId!,
          saleDate: _saleDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          items: items,
        );

    setState(() => _saving = false);

    if (sale != null && mounted) {
      // Refresh customers list to update totals
      await ref.read(marketCustomersProvider.notifier).load();
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('حدث خطأ أثناء الحفظ'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(marketCustomersProvider);
    final fmt = NumberFormat('#,###', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل دين جديد'),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _submit,
              child: const Text('حفظ',
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
                  // Customer selector
                  DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    decoration: const InputDecoration(
                      labelText: 'الزبون',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    items: customersState.customers
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCustomerId = v),
                    validator: (v) => v == null ? 'يرجى اختيار الزبون' : null,
                  ),
                  const SizedBox(height: 16),

                  // Date picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary),
                    title: const Text('تاريخ الشراء'),
                    subtitle: Text(
                        DateFormat('yyyy/MM/dd', 'ar').format(_saleDate)),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _saleDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => _saleDate = picked);
                    },
                  ),
                  const Divider(),

                  // Items header
                  Row(
                    children: [
                      const Expanded(
                          child: Text('المواد المشتراة',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold))),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('إضافة مادة'),
                        onPressed: () {
                          setState(() => _items.add(_ItemRow()));
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('مسح باركود'),
                        onPressed: _scanBarcode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Items list
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
                                    icon: const Icon(Icons.remove_circle_outline,
                                        color: AppColors.error),
                                    onPressed: () =>
                                        setState(() => _items.removeAt(i)),
                                  ),
                              ],
                            ),
                            TextFormField(
                              controller: row.nameCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'اسم المادة',
                                  prefixIcon:
                                      Icon(Icons.inventory_2_rounded)),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'مطلوب'
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
                                        labelText: 'الكمية'),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'مطلوب';
                                      if (double.tryParse(v) == null)
                                        return 'رقم غير صحيح';
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
                                        labelText: 'السعر (د.ع)'),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'مطلوب';
                                      if (double.tryParse(v) == null)
                                        return 'رقم غير صحيح';
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
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            '${fmt.format(_total)} د.ع',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.primary),
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
                      labelText: 'ملاحظات (اختياري)',
                      prefixIcon: Icon(Icons.note_rounded),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('حفظ الدين'),
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
