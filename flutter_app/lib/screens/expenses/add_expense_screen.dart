import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../providers/categories_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/audio_service.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, this.initialData});
  final Map<String, dynamic>? initialData;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  bool _isRecording = false;
  bool _isProcessingVoice = false;
  List<ParsedExpenseItem>? _parsedItems;
  String? _transcript;
  bool _isSaving = false;

  String? get _editId => widget.initialData?['expense_id'] as String?;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _amountCtrl.text = (d['amount'] ?? '').toString();
      _descCtrl.text = d['description'] ?? '';
      _noteCtrl.text = d['note'] ?? '';
      _selectedCategoryId = d['category_id'] as String?;
      if (d['expense_date'] != null) {
        _selectedDate = DateTime.parse(d['expense_date'] as String);
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    AudioService.instance.cancelRecording();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      setState(() => _isProcessingVoice = true);
      final path = await AudioService.instance.stopRecording();
      setState(() => _isRecording = false);
      if (path != null) await _processVoice(path);
      setState(() => _isProcessingVoice = false);
    } else {
      final started = await AudioService.instance.startRecording();
      if (started) setState(() => _isRecording = true);
    }
  }

  Future<void> _processVoice(String path) async {
    final l = AppLocalizations.of(context);
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(path, filename: 'voice.m4a'),
      });
      final data = await ApiService.instance.postFormData(
        ApiConstants.voiceParse,
        formData,
      );
      final response = VoiceParseResponse.fromJson(data as Map<String, dynamic>);
      setState(() {
        _transcript = response.transcript;
        _parsedItems = response.parsedExpenses;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveManual() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final l = AppLocalizations.of(context);
    final payload = {
      if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
      'amount': double.parse(_amountCtrl.text.replaceAll(',', '')),
      'description': _descCtrl.text.trim(),
      'expense_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'is_recurring': false,
      if (_noteCtrl.text.isNotEmpty) 'note': _noteCtrl.text.trim(),
    };

    bool ok;
    if (_editId != null) {
      ok = await ref.read(expensesProvider.notifier).update(_editId!, payload);
    } else {
      final result = await ref.read(expensesProvider.notifier).create(payload);
      ok = result != null;
    }

    setState(() => _isSaving = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editId != null ? l.expenseUpdated : l.expenseAdded),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  Future<void> _saveVoiceParsed() async {
    if (_parsedItems == null || _parsedItems!.isEmpty) return;
    setState(() => _isSaving = true);
    final l = AppLocalizations.of(context);

    final expenses = _parsedItems!
        .map((item) => item.toExpenseCreateJson())
        .toList();

    final ok = await ref.read(expensesProvider.notifier).createBulk(expenses);
    setState(() => _isSaving = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.expenseAdded), backgroundColor: AppColors.success),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editId != null ? l.edit : l.addExpense),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── Voice Section ────────────────────────────────────────────
            if (_editId == null) ...[
              _VoiceSectionWidget(
                l: l,
                isRecording: _isRecording,
                isProcessing: _isProcessingVoice,
                onToggle: _toggleRecording,
                transcript: _transcript,
              ).animate().fadeIn(),

              if (_parsedItems != null && _parsedItems!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ParsedExpensesReview(
                  l: l,
                  items: _parsedItems!,
                  categoriesAsync: categoriesAsync,
                  lang: lang,
                  onSave: _saveVoiceParsed,
                  isSaving: _isSaving,
                  onDiscard: () => setState(() {
                    _parsedItems = null;
                    _transcript = null;
                  }),
                ).animate().fadeIn().slideY(begin: 0.1),
              ],

              const Divider(height: 40),
              Align(
                child: Text(
                  l.isArabic ? '— أو أدخل يدوياً —' : '— or enter manually —',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─── Manual Form ──────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Amount
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l.amount,
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l.amountRequired;
                      if (double.tryParse(v.replaceAll(',', '')) == null) return l.invalidAmount;
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Category
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cats) => DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: InputDecoration(labelText: l.category),
                      items: cats.map((cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Row(
                          children: [
                            Text(cat.icon),
                            const SizedBox(width: 8),
                            Text(cat.localName(lang)),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descCtrl,
                    decoration: InputDecoration(labelText: l.description),
                  ),

                  const SizedBox(height: 16),

                  // Date picker
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('d MMMM yyyy', lang == 'ar' ? 'ar' : 'en').format(_selectedDate),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Note
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(labelText: l.note),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 32),

                  if (_isSaving)
                    const CircularProgressIndicator(color: AppColors.primary)
                  else
                    ElevatedButton(
                      onPressed: _saveManual,
                      child: Text(l.save),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Voice Section Widget ──────────────────────────────────────────────────────

class _VoiceSectionWidget extends StatelessWidget {
  const _VoiceSectionWidget({
    required this.l,
    required this.isRecording,
    required this.isProcessing,
    required this.onToggle,
    this.transcript,
  });

  final AppLocalizations l;
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onToggle;
  final String? transcript;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(l.voiceInput, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: isProcessing ? null : onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isRecording
                  ? AppColors.error
                  : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? AppColors.error : AppColors.primary)
                      .withOpacity(0.4),
                  blurRadius: isRecording ? 30 : 15,
                  spreadRadius: isRecording ? 8 : 0,
                ),
              ],
            ),
            child: isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isProcessing
              ? l.processing
              : isRecording
                  ? l.listening
                  : l.tapToSpeak,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isRecording ? AppColors.error : null,
              ),
        ),
        if (transcript != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '"$transcript"',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Parsed Expenses Review ────────────────────────────────────────────────────

class _ParsedExpensesReview extends ConsumerWidget {
  const _ParsedExpensesReview({
    required this.l,
    required this.items,
    required this.categoriesAsync,
    required this.lang,
    required this.onSave,
    required this.isSaving,
    required this.onDiscard,
  });

  final AppLocalizations l;
  final List<ParsedExpenseItem> items;
  final AsyncValue<List<CategoryModel>> categoriesAsync;
  final String lang;
  final VoidCallback onSave;
  final bool isSaving;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = categoriesAsync.value ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Text(l.parsedExpenses, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                onPressed: onDiscard,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const Divider(),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                // Auto-match category icon
                () {
                  final matched = cats.cast<CategoryModel?>().firstWhere(
                    (c) => c!.nameAr.contains(item.categoryHint) ||
                        c.nameEn.toLowerCase().contains(item.categoryHint.toLowerCase()) ||
                        item.categoryHint.contains(c.nameAr),
                    orElse: () => null,
                  );
                  item.resolvedCategoryId = matched?.id;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(matched?.icon ?? '💰', style: const TextStyle(fontSize: 18)),
                  );
                }(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description, style: Theme.of(context).textTheme.bodyMedium),
                      Text(item.categoryHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                Text(
                  '${item.amount.toStringAsFixed(0)} ${item.currency}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
          isSaving
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l.confirmExpenses),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
        ],
      ),
    );
  }
}
