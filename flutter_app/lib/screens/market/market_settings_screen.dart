import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class MarketSettingsScreen extends ConsumerStatefulWidget {
  const MarketSettingsScreen({super.key});

  @override
  ConsumerState<MarketSettingsScreen> createState() =>
      _MarketSettingsScreenState();
}

class _MarketSettingsScreenState extends ConsumerState<MarketSettingsScreen> {
  final _storeCtrl = TextEditingController();
  int _overdueDays = 30;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _storeCtrl.text = user?.storeName ?? '';
    _overdueDays = user?.marketOverdueDays ?? 30;
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ApiService.instance.patch(ApiConstants.marketSettings, data: {
        'store_name': _storeCtrl.text.trim(),
        'market_overdue_days': _overdueDays,
      });
      // Refresh auth user
      final data = await ApiService.instance.get(ApiConstants.me);
      // Update auth state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الإعدادات'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المحل')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Store name
                TextField(
                  controller: _storeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المحل / الماركت',
                    prefixIcon: Icon(Icons.store_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Overdue threshold
                Text(
                  'عتبة التنبيه بالديون المتأخرة',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'سيتم تنبيهك بالزبائن الذين لم يسددوا خلال $_overdueDays يوم',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondaryLight),
                ),
                Slider(
                  value: _overdueDays.toDouble(),
                  min: 7,
                  max: 180,
                  divisions: 173,
                  label: '$_overdueDays يوم',
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _overdueDays = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('7 أيام',
                        style: TextStyle(color: Colors.grey.shade500)),
                    Text('$_overdueDays يوم',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text('180 يوم',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ الإعدادات'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(14)),
                ),
              ],
            ),
    );
  }
}
