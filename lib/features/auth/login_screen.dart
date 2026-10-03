import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/router.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/auth/forgot_password_screen.dart';
import 'package:smart_campus/features/auth/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  String _role = 'student';
  bool _remember = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().lastLoginId().then((v) {
      if (mounted && v != null && _id.text.isEmpty) _id.text = v;
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final err = await auth.login(
          loginId: _id.text, password: _pw.text, role: _role, remember: _remember);
      if (!mounted) return;
      if (err != null) {
        setState(() => _error = err);
      } else {
        AppRouter.toHome(context, auth.user!);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillDemo() {
    setState(() {
      _error = null;
      if (_role == 'admin') {
        _id.text = AppStrings.adminEmail;
        _pw.text = AppStrings.adminPassword;
      } else {
        _id.text = AppStrings.demoStudentId;
        _pw.text = AppStrings.defaultStudentPassword;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset('assets/logo.png', width: 84, height: 84),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(AppStrings.collegeName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    Text('Welcome back',
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Sign in to continue to Smart Campus',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 22),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'admin',
                            label: Text('Admin'),
                            icon: Icon(Icons.admin_panel_settings_outlined)),
                        ButtonSegment(
                            value: 'student',
                            label: Text('Student'),
                            icon: Icon(Icons.school_outlined)),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() {
                        _role = s.first;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _id,
                      label: _role == 'admin' ? 'Admin email' : 'Email / Student ID',
                      icon: Icons.person_outline,
                      keyboard: TextInputType.emailAddress,
                      action: TextInputAction.next,
                      validator: Validators.loginId,
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                      controller: _pw,
                      validator: Validators.password,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v ?? false),
                        ),
                        const Text('Remember me'),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(role: _role))),
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: scheme.onErrorContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!,
                                  style: TextStyle(color: scheme.onErrorContainer)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PrimaryButton(label: 'Login', loading: _loading, onPressed: _submit),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: _fillDemo,
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: Text('Fill demo ${_role == 'admin' ? 'admin' : 'student'} login'),
                      ),
                    ),
                    if (_role == 'student')
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('New student?'),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              child: const Text('Create account'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
