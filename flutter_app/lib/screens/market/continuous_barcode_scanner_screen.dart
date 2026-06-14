import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../models/market_model.dart';
import '../../services/api_service.dart';

/// A result from a single barcode scan.
class _ScanResult {
  final String barcode;
  final MarketProductModel? product; // null = not found in catalog
  _ScanResult({required this.barcode, this.product});
}

/// Continuous barcode scanner that keeps the camera open.
///
/// Each time a barcode is detected, the corresponding catalog product is
/// looked up and displayed.  Unknown barcodes show a quick-add prompt.
///
/// Returns `List<MarketProductModel>` — all found products accumulated
/// during the session.  Callers (sales screens) can add them in bulk.
class ContinuousBarcodeScannerScreen extends StatefulWidget {
  const ContinuousBarcodeScannerScreen({super.key});

  @override
  State<ContinuousBarcodeScannerScreen> createState() =>
      _ContinuousBarcodeScannerScreenState();
}

class _ContinuousBarcodeScannerScreenState
    extends State<ContinuousBarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  // Debounce: ignore same barcode within 2 seconds
  String? _lastBarcode;
  DateTime _lastDetect = DateTime(2000);

  // Current detection result (shown in banner)
  _ScanResult? _current;
  bool _looking = false;

  // Accumulated found products
  final List<MarketProductModel> _foundProducts = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    final now = DateTime.now();
    if (code == _lastBarcode &&
        now.difference(_lastDetect) < const Duration(seconds: 2)) {
      return; // debounce same barcode
    }
    _lastBarcode = code;
    _lastDetect = now;

    if (_looking) return; // still resolving previous
    _looking = true;

    HapticFeedback.lightImpact();

    final product = await ApiService.instance.getProductByBarcode(code);

    if (!mounted) return;
    _looking = false;

    final result = _ScanResult(barcode: code, product: product);

    setState(() {
      _current = result;
      if (product != null) {
        // Add to accumulated list (avoid duplicate by id)
        if (!_foundProducts.any((p) => p.id == product.id)) {
          _foundProducts.add(product);
        }
      }
    });
  }

  /// Quick-add dialog for unknown barcodes.
  Future<void> _quickAddProduct(String barcode) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final result = await showModalBottomSheet<MarketProductModel?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const Text(
                  'إضافة منتج للكتالوج',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                // Show barcode
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_rounded,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          barcode,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    prefixIcon: Icon(Icons.inventory_2_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'مطلوب' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
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
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSt(() => saving = true);
                          try {
                            final product =
                                await ApiService.instance.createProduct(
                              name: nameCtrl.text.trim(),
                              unitPrice:
                                  double.parse(priceCtrl.text.trim()),
                              barcode: barcode,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(product);
                          } catch (e) {
                            setSt(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: AppColors.error,
                              ));
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('حفظ وإضافة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();

    if (result != null && mounted) {
      setState(() {
        _foundProducts.add(result);
        _current = _ScanResult(barcode: barcode, product: result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح الباركود'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_rounded),
            tooltip: 'الفلاش',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scanning frame overlay
          _ScanFrame(),

          // ── Detection result banner ──────────────────────────────────
          if (_current != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _DetectionCard(
                result: _current!,
                onAddProduct: () => _quickAddProduct(_current!.barcode),
              ),
            ),

          // ── Bottom bar ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
              ),
              child: Row(
                children: [
                  // Item count badge
                  if (_foundProducts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${_foundProducts.length} منتج',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'ضع الباركود داخل الإطار',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),

                  const Spacer(),

                  // Done button
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(_foundProducts),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_foundProducts.isEmpty ? 'إغلاق' : 'إضافة للبيع'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _foundProducts.isEmpty
                          ? Colors.white24
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Widgets ────────────────────────────────────

class _DetectionCard extends StatelessWidget {
  final _ScanResult result;
  final VoidCallback onAddProduct;

  const _DetectionCard({required this.result, required this.onAddProduct});

  @override
  Widget build(BuildContext context) {
    final found = result.product != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: found
            ? Colors.green.shade800.withOpacity(0.92)
            : Colors.red.shade800.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            found
                ? Icons.check_circle_outline_rounded
                : Icons.highlight_off_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: found
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.product!.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'IQD ${_fmt(result.product!.unitPrice)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'غير موجود في الكتالوج',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Text(
                        _shortBarcode(result.barcode),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ],
                  ),
          ),
          if (!found) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onAddProduct,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white60),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('إضافة', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final s = v.toInt().toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return v.toString();
  }

  String _shortBarcode(String bc) =>
      bc.length > 14 ? '${bc.substring(0, 7)}…${bc.substring(bc.length - 5)}' : bc;
}

/// Translucent overlay with a centred scanning frame.
class _ScanFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black45;
    const rectSize = 240.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 30;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: rectSize, height: rectSize);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()
          ..addRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(10))),
      ),
      dimPaint,
    );

    const cornerLen = 24.0;
    const strokeW = 3.5;
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final corner in [
      [rect.topLeft, const Offset(cornerLen, 0), const Offset(0, cornerLen)],
      [rect.topRight, const Offset(-cornerLen, 0), const Offset(0, cornerLen)],
      [
        rect.bottomLeft,
        const Offset(cornerLen, 0),
        const Offset(0, -cornerLen)
      ],
      [
        rect.bottomRight,
        const Offset(-cornerLen, 0),
        const Offset(0, -cornerLen)
      ],
    ]) {
      final origin = corner[0] as Offset;
      canvas.drawLine(origin, origin + (corner[1] as Offset), paint);
      canvas.drawLine(origin, origin + (corner[2] as Offset), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
