import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  bool _obscure = true;
  String _selectedLang = 'ar';
  String _selectedCurrency = 'IQD';
  String _selectedRole = 'user';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _storeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          fullName: _nameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          language: _selectedLang,
          currency: _selectedCurrency,
          role: _selectedRole,
          storeName: _selectedRole == 'market_owner' ? _storeCtrl.text.trim() : null,
        );
    final error = ref.read(authProvider).error;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/login'),
        ),
        title: Text(l.register),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.fullName,
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? l.fieldRequired : null,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.email,
                    prefixIcon: const Icon(Icons.email_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.fieldRequired;
                    if (!v.contains('@')) return l.invalidEmail;
                    return null;
                  },
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.phoneNumber,
                    prefixIcon: const Icon(Icons.phone_rounded),
                    hintText: '07xxxxxxxxx',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.fieldRequired;
                    final digits = v.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
                    if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) return l.invalidPhone;
                    return null;
                  },
                ).animate().fadeIn(delay: 175.ms).slideY(begin: 0.1),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.password,
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.fieldRequired;
                    if (v.length < 8) return l.passwordTooShort;
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) {
                    if (v != _passCtrl.text) return l.passwordsNotMatch;
                    return null;
                  },
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // Language & Currency row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLang,
                        decoration: InputDecoration(labelText: l.language),
                        items: [
                          DropdownMenuItem(value: 'ar', child: Text(l.arabic)),
                          DropdownMenuItem(value: 'en', child: Text(l.english)),
                        ],
                        onChanged: (v) => setState(() => _selectedLang = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: InputDecoration(labelText: l.currency),
                        items: const [
                          DropdownMenuItem(value: 'IQD', child: Text('IQD — دينار')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                          DropdownMenuItem(value: 'AED', child: Text('AED')),
                          DropdownMenuItem(value: 'KWD', child: Text('KWD')),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedCurrency = v!),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                // ── Role selector ──────────────────────────────────
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'نوع الحساب',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _RoleCard(
                      icon: Icons.person_rounded,
                      label: 'مستخدم عادي',
                      sublabel: 'تتبع مصاريفك الشخصية',
                      selected: _selectedRole == 'user',
                      onTap: () => setState(() => _selectedRole = 'user'),
                    ),
                    const SizedBox(width: 12),
                    _RoleCard(
                      icon: Icons.storefront_rounded,
                      label: 'صاحب ماركت',
                      sublabel: 'إدارة ديون الزبائن',
                      selected: _selectedRole == 'market_owner',
                      onTap: () => setState(() => _selectedRole = 'market_owner'),
                    ),
                  ],
                ).animate().fadeIn(delay: 310.ms),

                // ── Store name (only for market_owner) ─────────────
                if (_selectedRole == 'market_owner') ...[   
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _storeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المحل / الماركت',
                      prefixIcon: Icon(Icons.store_rounded),
                    ),
                    validator: (v) {
                      if (_selectedRole == 'market_owner' &&
                          (v == null || v.trim().isEmpty)) {
                        return 'اسم المحل مطلوب';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1),
                ],

                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isLoading
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : ElevatedButton(
                          onPressed: _submit,
                          child: Text(l.register),
                        ).animate().fadeIn(delay: 350.ms),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l.haveAccount),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(l.login,
                          style: const TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Role Card Widget ────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Colors.grey.shade300;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(color: color, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? AppColors.primary : null)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
