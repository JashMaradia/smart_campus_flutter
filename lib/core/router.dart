import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/features/admin/admin_shell.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/auth/login_screen.dart';
import 'package:smart_campus/features/student/student_shell.dart';

/// Role based routing. A student can never reach the admin shell because the
/// shell is chosen from the signed in user's role only.
class AppRouter {
  static Widget homeFor(AppUser user) =>
      user.role == 'admin' ? const AdminShell() : const StudentShell();

  static void toLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  static void toHome(BuildContext context, AppUser user) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeFor(user)),
      (_) => false,
    );
  }

  static Future<void> logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Logout',
      message: 'Do you want to sign out of Smart Campus?',
      confirmLabel: 'Logout',
    );
    if (!ok || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (context.mounted) toLogin(context);
  }
}
