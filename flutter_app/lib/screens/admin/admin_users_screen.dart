import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

final _adminUsersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final data = await ApiService.instance.get(ApiConstants.adminUsers);
  return (data as List<dynamic>)
      .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_adminUsersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUserDialog(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('حساب جديد'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث باسم أو بريد...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (users) {
                final filtered = _search.isEmpty
                    ? users
                    : users.where((u) =>
                        u.fullName.toLowerCase().contains(_search) ||
                        u.email.toLowerCase().contains(_search)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('لا توجد نتائج'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _UserTile(
                    user: filtered[i],
                    onRefresh: () => ref.invalidate(_adminUsersProvider),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateUserDialog(BuildContext context) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final storeCtrl = TextEditingController();
    String role = 'user';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('إنشاء حساب جديد'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    obscureText: true,
                    validator: (v) => (v?.length ?? 0) < 8 ? '8 أحرف على الأقل' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'الهاتف (اختياري)'),
                  ),
                  const SizedBox(height: 12),
                  // Role selector
                  Row(
                    children: [
                      const Text('النوع:'),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('مستخدم'),
                        selected: role == 'user',
                        onSelected: (_) => setDlgState(() => role = 'user'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('صاحب ماركت'),
                        selected: role == 'market_owner',
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) => setDlgState(() => role = 'market_owner'),
                      ),
                    ],
                  ),
                  if (role == 'market_owner') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: storeCtrl,
                      decoration: const InputDecoration(labelText: 'اسم المحل'),
                      validator: (v) =>
                          role == 'market_owner' && (v?.isEmpty ?? true) ? 'مطلوب' : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ApiService.instance.post(ApiConstants.adminUsers, data: {
                    'email': emailCtrl.text.trim(),
                    'password': passCtrl.text,
                    'full_name': nameCtrl.text.trim(),
                    if (phoneCtrl.text.trim().isNotEmpty) 'phone_number': phoneCtrl.text.trim(),
                    'role': role,
                    if (role == 'market_owner') 'store_name': storeCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(_adminUsersProvider);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.onRefresh});
  final UserModel user;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = user.isMarketOwner ? AppColors.warning : AppColors.primary;
    final roleLabel = user.isMarketOwner ? '🏪 ماركت' : '👤 مستخدم';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user.fullName, overflow: TextOverflow.ellipsis)),
            if (user.isAdmin)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('أدمن',
                    style: TextStyle(fontSize: 10, color: AppColors.error)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(roleLabel,
                  style: TextStyle(fontSize: 10, color: roleColor)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(fontSize: 11)),
            if (user.isMarketOwner && user.storeName != null)
              Text('المحل: ${user.storeName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.warning)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, ref, action),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'set_role',
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, size: 16),
                const SizedBox(width: 8),
                Text(user.isMarketOwner ? 'تحويل إلى مستخدم عادي' : 'تحويل إلى صاحب ماركت'),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                SizedBox(width: 8),
                Text('حذف', style: TextStyle(color: AppColors.error)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    if (action == 'set_role') {
      await _showSetRoleDialog(context, ref);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حذف الحساب'),
          content: Text('هل تريد حذف حساب ${user.fullName}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ApiService.instance.delete('${ApiConstants.adminUsers}/${user.id}');
        onRefresh();
      }
    }
  }

  Future<void> _showSetRoleDialog(BuildContext context, WidgetRef ref) async {
    final storeCtrl = TextEditingController(text: user.storeName ?? '');
    final newRole = user.isMarketOwner ? 'user' : 'market_owner';

    if (newRole == 'user') {
      // Direct downgrade
      await ApiService.instance.patch(
        '${ApiConstants.adminUsers}/${user.id}/set-role',
        data: {'role': 'user'},
      );
      onRefresh();
      return;
    }

    // Need store name for upgrade
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحويل إلى صاحب ماركت'),
        content: TextField(
          controller: storeCtrl,
          decoration: const InputDecoration(labelText: 'اسم المحل'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (storeCtrl.text.trim().isEmpty) return;
              await ApiService.instance.patch(
                '${ApiConstants.adminUsers}/${user.id}/set-role',
                data: {'role': 'market_owner', 'store_name': storeCtrl.text.trim()},
              );
              if (ctx.mounted) Navigator.pop(ctx);
              onRefresh();
            },
            child: const Text('تحويل'),
          ),
        ],
      ),
    );
  }
}
