import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/shared/settings_screen.dart';

class ProfileAdminScreen extends StatelessWidget {
  const ProfileAdminScreen({super.key});

  Future<void> _edit(BuildContext context) async {
    final user = context.read<AuthProvider>().user!;
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              AppTextField(
                  controller: name,
                  label: 'Name',
                  icon: Icons.person_outline,
                  validator: (v) => Validators.required(v, 'Name')),
              const SizedBox(height: 12),
              AppTextField(
                  controller: phone,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  maxLength: 10,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: Validators.phone),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final p = phone.text.trim();
    // Dispose after the dialog's closing animation has finished using them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      phone.dispose();
    });
    if (ok != true || !context.mounted) return;
    final repo = context.read<CampusRepository>();
    final auth = context.read<AuthProvider>();
    await repo.updateUserProfile(user.id, name: n, phone: p);
    await auth.reload();
    if (context.mounted) showSnack(context, 'Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Profile',
      embedded: true,
      body: MaxWidth(
        width: 640,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                children: [
                  UserAvatar(name: user?.name ?? 'Admin', radius: 44),
                  const SizedBox(height: 12),
                  Text(user?.name ?? 'Admin',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const StatusChip('Administrator', Color(0xFF1E40AF)),
                ],
              ),
            ),
            const SectionHeader('Details'),
            AppCard(
              child: Column(
                children: [
                  InfoRow('Email', user?.email ?? '', icon: Icons.mail_outline),
                  InfoRow('Phone', user?.phone ?? '', icon: Icons.phone_outlined),
                  const InfoRow('Role', 'Administrator', icon: Icons.admin_panel_settings_outlined),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showChangePasswordDialog(context),
              icon: const Icon(Icons.lock_reset),
              label: const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}
