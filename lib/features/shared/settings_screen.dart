import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/router.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/local/app_database.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';

/// Dialog used by both roles to change their own password.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final form = GlobalKey<FormState>();
  final oldPw = TextEditingController();
  final newPw = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  final done = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                PasswordField(controller: oldPw, label: 'Current password'),
                const SizedBox(height: 12),
                PasswordField(
                    controller: newPw, label: 'New password', validator: Validators.password),
                const SizedBox(height: 12),
                PasswordField(
                    controller: confirm,
                    label: 'Confirm new password',
                    validator: Validators.confirm(() => newPw.text)),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              final auth = ctx.read<AuthProvider>();
              final repo = ctx.read<CampusRepository>();
              final user = auth.user!;
              if (!await repo.verifyPassword(user, oldPw.text)) {
                setLocal(() => error = 'The current password is incorrect.');
                return;
              }
              await repo.changePassword(user.id, newPw.text);
              await auth.reload();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
  oldPw.dispose();
  newPw.dispose();
  confirm.dispose();
  if (done == true && context.mounted) showSnack(context, 'Password updated');
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.admin, this.embedded = false});
  final bool admin;
  final bool embedded;

  Future<void> _backup(BuildContext context) async {
    try {
      final path = await AppDatabase.instance.backupToTemp();
      await Share.shareXFiles([XFile(path)], text: 'Smart Campus database backup');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Backup failed: $e', error: true);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null || !context.mounted) return;
    final ok = await confirmDialog(context,
        title: 'Restore backup',
        message: 'This replaces ALL current data with the selected backup file. Continue?',
        confirmLabel: 'Restore');
    if (!ok || !context.mounted) return;
    try {
      await AppDatabase.instance.restoreFrom(path);
      if (!context.mounted) return;
      await context.read<SettingsProvider>().load();
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      AppRouter.toLogin(context);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Reset demo data',
        message:
            'All data will be erased and the original sample data will be restored. You will be logged out.',
        confirmLabel: 'Reset');
    if (!ok || !context.mounted) return;
    try {
      await AppDatabase.instance.resetDemoData();
      if (!context.mounted) return;
      await context.read<SettingsProvider>().load();
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      AppRouter.toLogin(context);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Reset failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final scheme = Theme.of(context).colorScheme;
    return PageScaffold(
      title: 'Settings',
      embedded: embedded,
      body: MaxWidth(
        width: 640,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('Appearance'),
            AppCard(
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined)),
                    ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_outlined)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ),
            ),
            const SectionHeader('Account'),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showChangePasswordDialog(context),
              ),
            ),
            if (admin) ...[
              const SectionHeader('Data'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('Backup database'),
                      subtitle: const Text('Export all data as a .db file'),
                      onTap: () => _backup(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Restore from backup'),
                      subtitle: const Text('Replace current data with a backup file'),
                      onTap: () => _restore(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.delete_sweep_outlined, color: scheme.error),
                      title: Text('Reset demo data', style: TextStyle(color: scheme.error)),
                      subtitle: const Text('Erase everything and reload the sample data'),
                      onTap: () => _reset(context),
                    ),
                  ],
                ),
              ),
            ],
            const SectionHeader('About'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About Smart Campus'),
                    subtitle: const Text('Version 1.0.0'),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: AppStrings.appName,
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.school_rounded, size: 40),
                      children: const [
                        Text('${AppStrings.tagline}\n\nAn offline campus management app. All data is stored on this device in a local SQLite database.'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.logout, color: scheme.error),
                    title: Text('Logout', style: TextStyle(color: scheme.error)),
                    onTap: () => AppRouter.logout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
