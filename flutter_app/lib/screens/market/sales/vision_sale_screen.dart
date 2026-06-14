import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../utils/pick_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/market_model.dart';
import '../../../providers/market_customers_provider.dart';
import '../../../providers/market_sales_provider.dart';
import '../../../services/api_service.dart';
import '../continuous_barcode_scanner_screen.dart';

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
  bool _analysisDoneEmpty = false;
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
    // Guard: prevent opening the picker while a previous analysis is still running
    if (_analyzing) return;

    // pickImageFile() is platform-aware:
    //   â€¢ Web    â†’ fresh dart:html FileUploadInputElement (reliable repeated picks)
    //   â€¢ Native â†’ file_picker package
    final picked = await pickImageFile();
    if (picked == null) return;

    setState(() => _imageBytes = picked.bytes);
    await _analyzeImage(picked.bytes, picked.mime);
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
        _analysisDoneEmpty = true;
        _items.add(_ItemRow());
      } else {
        _analysisDoneEmpty = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ÙØ´Ù„ ØªØ­Ù„ÙŠÙ„ Ø§Ù„ØµÙˆØ±Ø©: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _items.add(_ItemRow()));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

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
        _analysisDoneEmpty = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ØªÙ…Øª Ø¥Ø¶Ø§ÙØ© ${found.length} Ù…Ù†ØªØ¬'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
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
        const SnackBar(content: Text('ÙŠØ±Ø¬Ù‰ Ø¥Ø¶Ø§ÙØ© Ù…Ù†ØªØ¬ ÙˆØ§Ø­Ø¯ Ø¹Ù„Ù‰ Ø§Ù„Ø£Ù‚Ù„')),
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
          content: Text('Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø­ÙØ¸'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ÙØ§ØªÙˆØ±Ø© Ø¨Ø§Ù„ÙƒØ§Ù…ÙŠØ±Ø§'),
        actions: [
          IconButton(
            tooltip: 'ÙˆØ¶Ø¹ Ø§Ù„ÙƒØ§Ù…ÙŠØ±Ø§ Ø§Ù„Ù…Ø¨Ø§Ø´Ø±',
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () => context
                .push('/market/live-vision-sale/${widget.customerId}'),
          ),
          IconButton(
            tooltip: 'Ù…Ø³Ø­ Ø¨Ø§Ø±ÙƒÙˆØ¯',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _scanBarcode,
          ),
          if (!_saving && _items.isNotEmpty && !_analyzing)
            TextButton(
              onPressed: _submit,
              child: const Text(
                'Ø­ÙØ¸',
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
                            'Ø§Ø¶ØºØ· Ù„Ø§Ù„ØªÙ‚Ø§Ø· ØµÙˆØ±Ø© Ø£Ùˆ Ø§Ø®ØªÙŠØ§Ø± Ù…Ù† Ø§Ù„Ù…Ø¹Ø±Ø¶',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 13),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ø³ÙŠØªÙ… ØªØ­Ù„ÙŠÙ„ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹ Ø¨Ø§Ù„Ø°ÙƒØ§Ø¡ Ø§Ù„Ø§ØµØ·Ù†Ø§Ø¹ÙŠ',
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
                      Text('Ø¬Ø§Ø±ÙŠ ØªØ­Ù„ÙŠÙ„ Ø§Ù„ØµÙˆØ±Ø© Ø¨Ø§Ù„Ø°ÙƒØ§Ø¡ Ø§Ù„Ø§ØµØ·Ù†Ø§Ø¹ÙŠ...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (_items.isNotEmpty) ...[
              if (_analysisDoneEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border:
                        Border.all(color: Colors.amber.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ù„Ù… ÙŠØªÙ… Ø§Ø³ØªØ®Ø±Ø§Ø¬ Ù…Ù†ØªØ¬Ø§Øª ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹. Ø£Ø¶ÙÙ‡Ø§ ÙŠØ¯ÙˆÙŠØ§Ù‹.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Text('Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª Ø§Ù„Ù…Ø³ØªØ®Ø±Ø¬Ø©',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map(
                  (e) => _buildItemRow(e.key, e.value)),
              TextButton.icon(
                onPressed: () => setState(() => _items.add(_ItemRow())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ø¥Ø¶Ø§ÙØ© Ù…Ù†ØªØ¬'),
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
                    const Text('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${fmt.format(_total)} Ø¯.Ø¹',
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
                  labelText: 'Ù…Ù„Ø§Ø­Ø¸Ø© (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
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
                label: Text(_saving ? 'Ø¬Ø§Ø±ÙŠ Ø§Ù„Ø­ÙØ¸...' : 'Ø­ÙØ¸ Ø§Ù„ÙØ§ØªÙˆØ±Ø©'),
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
                  labelText: 'Ø§Ù„Ù…Ù†ØªØ¬',
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
                  labelText: 'ÙƒÙ…ÙŠØ©',
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
                  labelText: 'Ø³Ø¹Ø±',
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
