import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

/// Offline password reset: verify ID + email + date of birth, then set a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.role});
  final String role;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _verifyForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _email = TextEditingController();
  final _dob = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _dobValue;
  AppUser? _verified;
  bool _loading = false;
  String? _error;

  bool get _isAdmin => widget.role == 'admin';

  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    _dob.dispose();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final d = await pickDate(context, _dobValue ?? DateTime(2004, 1, 1),
        first: DateTime(1950), last: DateTime.now());
    if (d != null) {
      setState(() {
        _dobValue = d;
        _dob.text = Fmt.date(d);
      });
    }
  }

  Future<void> _verify() async {
    if (!_verifyForm.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await context.read<CampusRepository>().verifyRecovery(
          loginId: _id.text, email: _email.text, dob: _dobValue!);
      if (!mounted) return;
      if (u == null || u.role != widget.role) {
        setState(() => _error = 'The details do not match any ${_isAdmin ? 'admin' : 'student'} account.');
      } else {
        setState(() => _verified = u);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<CampusRepository>().changePassword(_verified!.id, _pw.text);
      if (!mounted) return;
      showSnack(context, 'Password updated. Please log in.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update the password: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_verified == null)
                    Form(
                      key: _verifyForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Confirm your identity to reset the password. '
                            'This works offline using your registered details.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          AppTextField(
                            controller: _id,
                            label: _isAdmin ? 'Admin email' : 'Student ID',
                            icon: Icons.person_outline,
                            action: TextInputAction.next,
                            validator: (v) => Validators.required(v, 'This field'),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _email,
                            label: 'Registered email',
                            icon: Icons.mail_outline,
                            keyboard: TextInputType.emailAddress,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _dob,
                            label: 'Date of birth',
                            icon: Icons.cake_outlined,
                            readOnly: true,
                            onTap: _pickDob,
                            validator: (v) => Validators.required(v, 'Date of birth'),
                          ),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(_error!,
                                  style: TextStyle(color: scheme.onErrorContainer)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          PrimaryButton(label: 'Verify', loading: _loading, onPressed: _verify),
                        ],
                      ),
                    )
                  else
                    Form(
                      key: _resetForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Verified. Hello ${_verified!.name}, choose a new password.',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 20),
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
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                              label: 'Update password', loading: _loading, onPressed: _reset),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
