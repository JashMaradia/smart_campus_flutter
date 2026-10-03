import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/domain/campus_repository.dart';

/// Offline account activation: the admin adds the student first, then the
/// student confirms Student ID + email and sets a password.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<CampusRepository>();
    try {
      final err = await repo.activateStudentAccount(
          studentId: _id.text, email: _email.text, password: _pw.text);
      if (!mounted) return;
      if (err != null) {
        setState(() => _error = err);
      } else {
        showSnack(context, 'Account created. You can log in now.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create the account: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                    Text(
                      'Enter the Student ID and email registered by your college. '
                      'Then choose a password for your account.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _id,
                      label: 'Student ID',
                      icon: Icons.badge_outlined,
                      action: TextInputAction.next,
                      validator: (v) => Validators.required(v, 'Student ID'),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _email,
                      label: 'Registered email',
                      icon: Icons.mail_outline,
                      keyboard: TextInputType.emailAddress,
                      action: TextInputAction.next,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),
                    PasswordField(
                        controller: _pw,
                        label: 'New password',
                        validator: Validators.password,
                        action: TextInputAction.next),
                    const SizedBox(height: 14),
                    PasswordField(
                      controller: _confirm,
                      label: 'Confirm password',
                      validator: Validators.confirm(() => _pw.text),
                      action: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PrimaryButton(label: 'Create account', loading: _loading, onPressed: _submit),
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
