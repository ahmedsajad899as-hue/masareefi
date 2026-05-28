import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/market_customers_provider.dart';
import '../../../providers/market_sales_provider.dart';
import '../../../services/api_service.dart';

class _ItemRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController(text: '0');
  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class VisionSaleScreen extends ConsumerStatefulWidget {
  const VisionSaleScreen({super.key, required this.customerId});
  final String customerId;

  @override
  ConsumerState<VisionSaleScreen> createState() => _VisionSaleScreenState();
}

class _VisionSaleScreenState extends ConsumerState<VisionSaleScreen> {
  final _notesCtrl = TextEditingController();
  final List<_ItemRow> _items = [];
  bool _analyzing = false;
  bool _saving = false;
  Uint8List? _imageBytes;

  final fmt = NumberFormat('#,###', 'ar');

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

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;

    final ext = (file.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    setState(() => _imageBytes = bytes);
    await _analyzeImage(bytes, mime);
  }

  Future<void> _analyzeImage(Uint8List bytes, String mime) async {
    setState(() => _analyzing = true);
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: 'photo.${mime.split('/').last}',
          contentType: DioMediaType.parse(mime),
        ),
      });
      final data = await ApiService.instance
          .postFormData(ApiConstants.marketVisionAnalyze, formData);
      final List rawItems = data['items'] as List? ?? [];
      for (final r in _items) {
        r.dispose();
      }
      _items.clear();
      for (final item in rawItems) {
        final row = _ItemRow();
        row.nameCtrl.text = item['product_name'] ?? '';
        row.qtyCtrl.text = (item['quantity'] ?? 1).toString();
        row.priceCtrl.text = (item['unit_price'] ?? 0).toString();
        _items.add(row);
      }
      if (_items.isEmpty) {
        _items.add(_ItemRow());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحليل الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        _items.add(_ItemRow());
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);

    final items = _items
        .where((r) => r.nameCtrl.text.trim().isNotEmpty)
        .map((r) => {
              'product_name': r.nameCtrl.text.trim(),
              'quantity': double.tryParse(r.qtyCtrl.text) ?? 1,
              'unit_price': double.tryParse(r.priceCtrl.text) ?? 0,
            })
        .toList();

    if (items.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة منتج واحد على الأقل')),
      );
      return;
    }

    final sale = await ref.read(marketSalesProvider.notifier).createSale(
          customerId: widget.customerId,
          saleDate: DateTime.now(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          items: items,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    if (sale != null) {
      await ref.read(marketCustomersProvider.notifier).load();
      if (mounted) context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء الحفظ'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة بالكاميرا'),
        actions: [
          if (!_saving && _items.isNotEmpty && !_analyzing)
            TextButton(
              onPressed: _submit,
              child: const Text(
                'حفظ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _analyzing ? null : _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 2),
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded,
                              size: 56, color: AppColors.primary),
                          SizedBox(height: 10),
                          Text(
                            'اضغط لالتقاط صورة أو اختيار من المعرض',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 13),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'سيتم تحليل المنتجات تلقائياً بالذكاء الاصطناعي',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_analyzing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('جاري تحليل الصورة بالذكاء الاصطناعي...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (_items.isNotEmpty) ...[
              const Text('المنتجات المستخرجة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map(
                  (e) => _buildItemRow(e.key, e.value)),
              TextButton.icon(
                onPressed: () => setState(() => _items.add(_ItemRow())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة منتج'),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${fmt.format(_total)} د.ع',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الفاتورة'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, _ItemRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: row.nameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'المنتج',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: row.qtyCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'كمية',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: row.priceCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => setState(() {
                row.dispose();
                _items.removeAt(index);
              }),
            ),
          ],
        ),
      ),
    );
  }
}
