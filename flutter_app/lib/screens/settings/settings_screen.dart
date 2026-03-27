import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settings),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ─── Profile Card ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      child: Text(
                        auth.user?.fullName.isNotEmpty == true
                            ? auth.user!.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.user?.fullName ?? '',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            auth.user?.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                      onPressed: () => _showEditProfile(context),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(),
          ),

          const SizedBox(height: 20),

          _SectionHeader(title: l.isArabic ? 'التفضيلات' : 'Preferences'),

          // ─── Language ────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.language_rounded, color: AppColors.primary),
            title: Text(l.language),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ar', label: Text('عربي')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {settings.language},
              onSelectionChanged: (v) =>
                  ref.read(settingsProvider.notifier).setLanguage(v.first),
            ),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ─── Theme ──────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded, color: AppColors.primary),
            title: Text(l.theme),
            trailing: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded, size: 18)),
                ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded, size: 18)),
                ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.auto_mode_rounded, size: 18)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) =>
                  ref.read(settingsProvider.notifier).setThemeMode(v.first),
            ),
          ),

          const Divider(indent: 16, endIndent: 16),

          // ─── Currency ────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.currency_exchange_rounded, color: AppColors.primary),
            title: Text(l.currency),
            trailing: DropdownButton<String>(
              value: settings.currency,
              underline: const SizedBox.shrink(),
              items: const ['IQD', 'USD', 'EUR', 'SAR', 'AED', 'KWD'].map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ).toList(),
              onChanged: (v) {
                if (v != null) ref.read(settingsProvider.notifier).setCurrency(v);
              },
            ),
          ),

          const SizedBox(height: 20),

          _SectionHeader(title: l.isArabic ? 'الأمان' : 'Security'),

          // ─── Change Password ─────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            title: Text(l.isArabic ? 'تغيير كلمة المرور' : 'Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showChangePassword(context),
          ),

          const SizedBox(height: 20),

          _SectionHeader(title: l.isArabic ? 'حول التطبيق' : 'About'),

          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            title: const Text('مصاريفي / Masareefi'),
            subtitle: const Text('v1.0.0'),
          ),

          const SizedBox(height: 20),

          // ─── Logout ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: Text(l.logout),
            ).animate().fadeIn(delay: 300.ms),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _showEditProfile(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final auth = ref.read(authProvider);
    final nameCtrl = TextEditingController(text: auth.user?.fullName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile'),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: l.isArabic ? 'الاسم الكامل' : 'Full Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(authProvider.notifier).updateProfile({'full_name': nameCtrl.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.isArabic ? 'تغيير كلمة المرور' : 'Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: l.isArabic ? 'كلمة المرور الحالية' : 'Current Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: l.isArabic ? 'كلمة المرور الجديدة' : 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.isArabic ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (currentCtrl.text.isEmpty || newCtrl.text.length < 6) return;
                final ok = await ref.read(authProvider.notifier).changePassword(
                  currentCtrl.text,
                  newCtrl.text,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(ok
                        ? (l.isArabic ? 'تم تغيير كلمة المرور' : 'Password changed')
                        : (l.isArabic ? 'فشل تغيير كلمة المرور' : 'Failed to change password')),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ));
                }
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.isArabic ? 'تسجيل الخروج' : 'Logout'),
        content: Text(l.isArabic ? 'هل تريد تسجيل الخروج؟' : 'Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
