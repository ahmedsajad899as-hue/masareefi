import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/market_model.dart';
import '../../../providers/market_products_provider.dart';
import '../barcode_scanner_screen.dart';

class MarketProductsScreen extends ConsumerStatefulWidget {
  /// If non-null, the "add product" form will pre-fill the barcode field and
  /// open immediately (used when a barcode is scanned but not found in catalog).
  final String? initialBarcode;

  const MarketProductsScreen({super.key, this.initialBarcode});

  @override
  ConsumerState<MarketProductsScreen> createState() =>
      _MarketProductsScreenState();
}

class _MarketProductsScreenState extends ConsumerState<MarketProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketProductsProvider.notifier).load();
      if (widget.initialBarcode != null) {
        _showProductForm(context, initialBarcode: widget.initialBarcode);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MarketProductModel> _filtered(List<MarketProductModel> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.barcodes.any((b) => b.toLowerCase().contains(q)))
        .toList();
  }

  /// Truncate a barcode string for compact display.
  String _shortBarcode(String bc) =>
      bc.length > 14 ? '${bc.substring(0, 7)}…${bc.substring(bc.length - 5)}' : bc;

  Future<void> _showProductForm(
    BuildContext ctx, {
    MarketProductModel? product,
    String? initialBarcode,
  }) async {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl =
        TextEditingController(text: product?.unitPrice.toString() ?? '');
    final newBarcodeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Start with existing barcodes; if new product with initialBarcode, pre-fill
    final initialBarcodes = product?.barcodes.toList() ??
        (initialBarcode != null ? [initialBarcode] : <String>[]);

    bool saving = false;

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        List<String> barcodes = List.from(initialBarcodes);

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) => SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text(
                    product == null ? 'إضافة منتج' : 'تعديل المنتج',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Name
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنتج',
                      prefixIcon: Icon(Icons.inventory_2_rounded),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'مطلوب' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // Price
                  TextFormField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'السعر (د.ع)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'مطلوب';
                      if (double.tryParse(v) == null) return 'رقم غير صحيح';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // ─── Barcodes section ────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.qr_code_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'الباركودات',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${barcodes.length}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Existing barcodes as chips
                  if (barcodes.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: barcodes.map((bc) {
                        final isFirst = barcodes.first == bc;
                        return Chip(
                          label: Text(
                            _shortBarcode(bc),
                            style: const TextStyle(
                                fontSize: 12, fontFamily: 'monospace'),
                          ),
                          avatar: isFirst
                              ? const Icon(Icons.star_rounded,
                                  size: 14, color: AppColors.primary)
                              : null,
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () =>
                              setSheetState(() => barcodes.remove(bc)),
                          backgroundColor:
                              AppColors.primary.withOpacity(0.08),
                          side: const BorderSide(
                              color: AppColors.primary, width: 0.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 8),

                  // Add new barcode row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: newBarcodeCtrl,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            hintText: 'أضف باركود جديد',
                            hintStyle:
                                TextStyle(color: Colors.grey.shade400),
                            prefixIcon:
                                const Icon(Icons.add_rounded, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Scan button
                      IconButton.outlined(
                        icon: const Icon(Icons.document_scanner_rounded),
                        tooltip: 'مسح الباركود',
                        onPressed: () async {
                          final scanned =
                              await Navigator.of(sheetCtx).push<String>(
                            MaterialPageRoute(
                                builder: (_) => const BarcodeScannerScreen()),
                          );
                          if (scanned != null) {
                            setSheetState(() {
                              if (!barcodes.contains(scanned)) {
                                barcodes.add(scanned);
                              }
                              newBarcodeCtrl.clear();
                            });
                          }
                        },
                      ),
                      // Add from text button
                      IconButton.filled(
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'إضافة',
                        style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        onPressed: () {
                          final val = newBarcodeCtrl.text.trim();
                          if (val.isEmpty) return;
                          setSheetState(() {
                            if (!barcodes.contains(val)) barcodes.add(val);
                            newBarcodeCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'النجمة ★ تشير إلى الباركود الأساسي',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => saving = true);

                            final name = nameCtrl.text.trim();
                            final price =
                                double.parse(priceCtrl.text.trim());

                            bool ok;
                            if (product == null) {
                              // ── New product ──
                              final primaryBarcode =
                                  barcodes.isEmpty ? null : barcodes.first;
                              final created = await ref
                                  .read(marketProductsProvider.notifier)
                                  .add(
                                    name: name,
                                    unitPrice: price,
                                    barcode: primaryBarcode,
                                  );
                              ok = created != null;
                              // Add extra barcodes
                              if (ok && created != null && barcodes.length > 1) {
                                for (final bc in barcodes.skip(1)) {
                                  await ref
                                      .read(marketProductsProvider.notifier)
                                      .addBarcode(created.id, bc);
                                }
                              }
                            } else {
                              // ── Edit existing product ──
                              final originalBarcodes = product.barcodes;
                              final added = barcodes
                                  .where((b) => !originalBarcodes.contains(b))
                                  .toList();
                              final removed = originalBarcodes
                                  .where((b) => !barcodes.contains(b))
                                  .toList();

                              final newPrimary =
                                  barcodes.isEmpty ? null : barcodes.first;
                              final primaryChanged =
                                  newPrimary != product.barcode;

                              ok = await ref
                                  .read(marketProductsProvider.notifier)
                                  .edit(
                                    product.id,
                                    name: name,
                                    unitPrice: price,
                                    barcode: primaryChanged ? newPrimary : null,
                                    clearBarcode: primaryChanged &&
                                        newPrimary == null,
                                  );

                              if (ok) {
                                // Remove old extra barcodes
                                for (final b in removed) {
                                  if (b == product.barcode) continue; // handled via PATCH
                                  await ref
                                      .read(marketProductsProvider.notifier)
                                      .removeBarcode(product.id, b);
                                }
                                // Add new extra barcodes
                                for (final b in added) {
                                  if (b == newPrimary && primaryChanged) continue;
                                  await ref
                                      .read(marketProductsProvider.notifier)
                                      .addBarcode(product.id, b);
                                }
                              }
                            }

                            if (sheetCtx.mounted) {
                              Navigator.of(sheetCtx).pop();
                              if (!ok) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text('حدث خطأ أثناء الحفظ'),
                                      backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    newBarcodeCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext ctx, MarketProductModel p) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${p.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await ref.read(marketProductsProvider.notifier).remove(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketProductsProvider);
    final fmt = NumberFormat('#,###', 'ar');
    final filtered = _filtered(state.products);

    return Scaffold(
      appBar: AppBar(
        title: const Text('كتالوج المنتجات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث باسم أو باركود...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 8),
                      Text(state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                        onPressed: () =>
                            ref.read(marketProductsProvider.notifier).load(),
                      ),
                    ],
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 72, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _query.isNotEmpty
                                ? 'لا توجد نتائج'
                                : 'لا توجد منتجات بعد\nاضغط + لإضافة منتج',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (ctx, i) {
                        final p = filtered[i];
                        // Build compact barcodes line
                        Widget? subtitle;
                        if (p.barcodes.isNotEmpty) {
                          subtitle = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_rounded,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  p.barcodes
                                      .map(_shortBarcode)
                                      .join('  ·  '),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (p.barcodes.length > 1) ...
                                [
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${p.barcodes.length}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ],
                            ],
                          );
                        }

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.12),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: subtitle,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${fmt.format(p.unitPrice)} د.ع',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<_Action>(
                                  onSelected: (a) {
                                    if (a == _Action.edit) {
                                      _showProductForm(context, product: p);
                                    } else {
                                      _confirmDelete(context, p);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: _Action.edit,
                                      child: Row(children: [
                                        Icon(Icons.edit_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('تعديل'),
                                      ]),
                                    ),
                                    PopupMenuItem(
                                      value: _Action.delete,
                                      child: Row(children: [
                                        Icon(Icons.delete_rounded,
                                            size: 18, color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('حذف',
                                            style: TextStyle(
                                                color: AppColors.error)),
                                      ]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('منتج جديد'),
      ),
    );
  }
}

enum _Action { edit, delete }


class MarketProductsScreen extends ConsumerStatefulWidget {
  /// If non-null, the "add product" form will pre-fill the barcode field and
  /// open immediately (used when a barcode is scanned but not found in catalog).
  final String? initialBarcode;

  const MarketProductsScreen({super.key, this.initialBarcode});

  @override
  ConsumerState<MarketProductsScreen> createState() =>
      _MarketProductsScreenState();
}

class _MarketProductsScreenState extends ConsumerState<MarketProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketProductsProvider.notifier).load();
      if (widget.initialBarcode != null) {
        _showProductForm(context, initialBarcode: widget.initialBarcode);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MarketProductModel> _filtered(List<MarketProductModel> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.barcode?.contains(q) ?? false))
        .toList();
  }

  Future<void> _showProductForm(
    BuildContext ctx, {
    MarketProductModel? product,
    String? initialBarcode,
  }) async {
    final nameCtrl =
        TextEditingController(text: product?.name ?? '');
    final priceCtrl =
        TextEditingController(text: product?.unitPrice.toString() ?? '');
    final barcodeCtrl = TextEditingController(
        text: product?.barcode ?? initialBarcode ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(
                  product == null ? 'إضافة منتج' : 'تعديل المنتج',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Name
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    prefixIcon: Icon(Icons.inventory_2_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // Price
                TextFormField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'السعر (د.ع)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    if (double.tryParse(v) == null) return 'رقم غير صحيح';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // Barcode
                TextFormField(
                  controller: barcodeCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'الباركود (اختياري)',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.document_scanner_rounded),
                      tooltip: 'مسح الباركود',
                      onPressed: () async {
                        final scanned =
                            await Navigator.of(sheetCtx).push<String>(
                          MaterialPageRoute(
                              builder: (_) => const BarcodeScannerScreen()),
                        );
                        if (scanned != null) {
                          setSheetState(() => barcodeCtrl.text = scanned);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() => saving = true);

                          final name = nameCtrl.text.trim();
                          final price = double.parse(priceCtrl.text.trim());
                          final barcode = barcodeCtrl.text.trim().isEmpty
                              ? null
                              : barcodeCtrl.text.trim();

                          bool ok;
                          if (product == null) {
                            final created =
                                await ref.read(marketProductsProvider.notifier).add(
                                      name: name,
                                      unitPrice: price,
                                      barcode: barcode,
                                    );
                            ok = created != null;
                          } else {
                            ok = await ref
                                .read(marketProductsProvider.notifier)
                                .edit(
                                  product.id,
                                  name: name,
                                  unitPrice: price,
                                  barcode: barcode,
                                  clearBarcode: barcode == null,
                                );
                          }

                          if (sheetCtx.mounted) {
                            Navigator.of(sheetCtx).pop();
                            if (!ok) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('حدث خطأ أثناء الحفظ'),
                                    backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    barcodeCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext ctx, MarketProductModel p) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${p.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await ref.read(marketProductsProvider.notifier).remove(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketProductsProvider);
    final fmt = NumberFormat('#,###', 'ar');
    final filtered = _filtered(state.products);

    return Scaffold(
      appBar: AppBar(
        title: const Text('كتالوج المنتجات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث باسم أو باركود...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 8),
                      Text(state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                        onPressed: () =>
                            ref.read(marketProductsProvider.notifier).load(),
                      ),
                    ],
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 72, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _query.isNotEmpty
                                ? 'لا توجد نتائج'
                                : 'لا توجد منتجات بعد\nاضغط + لإضافة منتج',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (ctx, i) {
                        final p = filtered[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.12),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: p.barcode != null
                                ? Row(
                                    children: [
                                      const Icon(Icons.qr_code_rounded,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(p.barcode!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontFamily: 'monospace')),
                                    ],
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${fmt.format(p.unitPrice)} د.ع',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<_Action>(
                                  onSelected: (a) {
                                    if (a == _Action.edit) {
                                      _showProductForm(context, product: p);
                                    } else {
                                      _confirmDelete(context, p);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: _Action.edit,
                                      child: Row(children: [
                                        Icon(Icons.edit_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('تعديل'),
                                      ]),
                                    ),
                                    PopupMenuItem(
                                      value: _Action.delete,
                                      child: Row(children: [
                                        Icon(Icons.delete_rounded,
                                            size: 18, color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('حذف',
                                            style: TextStyle(
                                                color: AppColors.error)),
                                      ]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('منتج جديد'),
      ),
    );
  }
}

enum _Action { edit, delete }
