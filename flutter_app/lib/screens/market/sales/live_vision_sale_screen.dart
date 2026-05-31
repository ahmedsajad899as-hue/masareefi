import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/market_customers_provider.dart';
import '../../../providers/market_sales_provider.dart';
import '../../../services/api_service.dart';

class _LiveItem {
  _LiveItem(this.name, this.qty, this.price);
  String name;
  double qty;
  double price;
}

class LiveVisionSaleScreen extends ConsumerStatefulWidget {
  const LiveVisionSaleScreen({super.key, required this.customerId});
  final String customerId;

  @override
  ConsumerState<LiveVisionSaleScreen> createState() =>
      _LiveVisionSaleScreenState();
}

class _LiveVisionSaleScreenState extends ConsumerState<LiveVisionSaleScreen> {
  CameraController? _controller;
  final String _sessionId = const Uuid().v4();
  final List<_LiveItem> _items = [];
  Timer? _captureTimer;

  bool _busy = false;
  bool _saving = false;
  bool _streaming = true;
  String _statusMsg = 'جاهز للتحليل المباشر';
  int _newCount = 0;
  int _dupCount = 0;

  final _fmt = NumberFormat('#,###', 'ar');

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _statusMsg = 'لا توجد كاميرا متاحة');
        return;
      }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final c = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = c;
      await c.initialize();
      if (!mounted) return;
      setState(() {});
      _startCaptureLoop();
    } catch (e) {
      if (mounted) {
        setState(() => _statusMsg = 'فشل تشغيل الكاميرا: $e');
      }
    }
  }

  void _startCaptureLoop() {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _captureOnce(),
    );
  }

  Future<void> _captureOnce() async {
    if (_busy ||
        !_streaming ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    _busy = true;
    XFile? shot;
    try {
      shot = await _controller!.takePicture();
      final bytes = await File(shot.path).readAsBytes();

      final form = FormData.fromMap({
        'session_id': _sessionId,
        'image': MultipartFile.fromBytes(
          bytes,
          filename: 'frame.jpg',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
      });
      final data = await ApiService.instance.postFormData(
        ApiConstants.marketVisionAnalyzeStream,
        form,
      );
      final status = data['status'] as String? ?? 'empty';

      if (status == 'duplicate') {
        _dupCount++;
        if (mounted) {
          setState(() => _statusMsg = 'نفس الإطار — تجاهل ($_dupCount)');
        }
      } else if (status == 'new') {
        final List rawItems = data['items'] as List? ?? [];
        int added = 0;
        for (final it in rawItems) {
          final name = (it['product_name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          final qty = (it['quantity'] as num?)?.toDouble() ?? 1;
          final price = (it['unit_price'] as num?)?.toDouble() ?? 0;
          final existing = _items.indexWhere((x) => x.name == name);
          if (existing >= 0) {
            _items[existing].qty += qty;
          } else {
            _items.add(_LiveItem(name, qty, price));
            added++;
          }
        }
        _newCount += added;
        if (mounted) {
          setState(() => _statusMsg =
              added > 0 ? 'أُضيف $added منتج جديد' : 'لم يُكتشف منتج جديد');
        }
      } else {
        if (mounted) setState(() => _statusMsg = 'لم يتم التعرف على منتج');
      }
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'خطأ: $e');
    } finally {
      if (shot != null) {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
      _busy = false;
    }
  }

  Future<void> _endSession() async {
    try {
      await ApiService.instance.postFormData(
        ApiConstants.marketVisionStreamEnd,
        FormData.fromMap({'session_id': _sessionId}),
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() {
      _saving = true;
      _streaming = false;
    });
    _captureTimer?.cancel();

    final payload = _items
        .map((it) => {
              'product_name': it.name,
              'quantity': it.qty,
              'unit_price': it.price,
            })
        .toList();

    final sale = await ref.read(marketSalesProvider.notifier).createSale(
          customerId: widget.customerId,
          saleDate: DateTime.now(),
          notes: null,
          items: payload,
        );
    if (!mounted) return;
    if (sale != null) {
      await ref.read(marketCustomersProvider.notifier).load();
      await _endSession();
      if (mounted) context.pop();
    } else {
      setState(() {
        _saving = false;
        _streaming = true;
      });
      _startCaptureLoop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('فشل الحفظ'), backgroundColor: AppColors.error),
      );
    }
  }

  double get _total => _items.fold(0.0, (s, it) => s + it.qty * it.price);

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.dispose();
    _endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('وضع الكاميرا المباشر')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'الوضع المباشر متاح على الموبايل فقط.\n'
              'على المتصفح استخدم وضع التقاط الصور العادي.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('كاميرا مباشرة'),
        actions: [
          IconButton(
            icon: Icon(_streaming ? Icons.pause_circle : Icons.play_circle),
            tooltip: _streaming ? 'إيقاف مؤقت' : 'استئناف',
            onPressed: () {
              setState(() => _streaming = !_streaming);
              if (_streaming) _startCaptureLoop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Camera preview ─────────────────────────────────────
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  Positioned.fill(child: CameraPreview(_controller!))
                else
                  Container(
                    color: Colors.black12,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _streaming ? Icons.videocam : Icons.videocam_off,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMsg,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'جديد:$_newCount · مكرر:$_dupCount',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Accumulated items list ─────────────────────────────
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'وجّه الكاميرا نحو المنتج\nسيُضاف تلقائياً عند التعرف',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          dense: true,
                          title: Text(it.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'الكمية: ${it.qty.toStringAsFixed(0)}  ·  '
                            'السعر: ${_fmt.format(it.price)} د.ع',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_fmt.format(it.qty * it.price)} د.ع',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () =>
                                    setState(() => _items.removeAt(i)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // ── Total + save ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'الإجمالي: ${_fmt.format(_total)} د.ع',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (_items.isEmpty || _saving) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? '...' : 'حفظ الفاتورة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
