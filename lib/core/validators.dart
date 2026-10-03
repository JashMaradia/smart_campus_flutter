/// Reusable form validators. Each returns an error message or null.
class Validators {
  static String? required(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    return RegExp(r'^\d{10}$').hasMatch(v.trim())
        ? null
        : 'Enter a 10 digit phone number';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  /// Email or student id.
  static String? loginId(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email or Student ID is required';
    final t = v.trim();
    if (t.contains('@')) return email(t);
    return t.length < 3 ? 'Enter a valid Student ID' : null;
  }

  static String? Function(String?) confirm(String Function() original) =>
      (v) {
        if (v == null || v.isEmpty) return 'Please confirm the password';
        return v == original() ? null : 'Passwords do not match';
      };

  static String? positiveInt(String? v, [String label = 'Value']) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = int.tryParse(v.trim());
    return (n == null || n <= 0) ? '$label must be a positive number' : null;
  }
}
