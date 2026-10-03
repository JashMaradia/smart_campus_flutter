import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_campus/core/utils.dart';

// ------------------------------------------------------------------ feedback
void showSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? scheme.error : null,
    ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial,
    {DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: last ?? DateTime(2100),
  );
}

Future<String?> pickTime(BuildContext context, String initialHHmm) async {
  final t = await showTimePicker(
      context: context, initialTime: Fmt.parseTime(initialHHmm));
  return t == null ? null : Fmt.timeOfDay(t);
}

// -------------------------------------------------------------------- layout
/// Keeps content readable on tablets by limiting its width.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 900});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child),
      );
}

/// Scaffold that hides its AppBar when embedded inside a navigation shell.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.embedded = false,
    this.fab,
    this.actions,
    this.bottom,
  });
  final String title;
  final Widget body;
  final bool embedded;
  final Widget? fab;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: embedded && bottom == null && (actions == null || actions!.isEmpty)
            ? null
            : AppBar(
                title: Text(title),
                actions: actions,
                bottom: bottom,
                automaticallyImplyLeading: !embedded,
              ),
        floatingActionButton: fab,
        body: body,
      );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color ?? scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String value, label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});
  final String label, value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 104,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- async states
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: message,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
}

/// Pulsing placeholder rows shown while data loads.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 6});
  final int count;
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 0.8).animate(_c),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: widget.count,
        itemBuilder: (_, __) => Container(
          height: 76,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

/// Runs a [Future] and renders loading, error and data states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SkeletonList();
          if (snap.hasError) {
            debugPrint('AsyncBody ERROR: ${snap.error}');
            return ErrorView(message: '${snap.error}', onRetry: onRetry);
          }
          if (!snap.hasData) {
            return const Center(child: Text('No data.'));
          }
          return builder(context, snap.data as T);
        },
      );
}

// ------------------------------------------------------------------- inputs
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboard,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.maxLines = 1,
    this.onChanged,
    this.formatters,
    this.action,
    this.onSubmitted,
    this.maxLength,
  });
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure, readOnly;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final Widget? suffix;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? formatters;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        validator: validator,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: obscure ? 1 : maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        inputFormatters: formatters,
        textInputAction: action,
        onFieldSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: suffix,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.action,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => AppTextField(
        controller: widget.controller,
        label: widget.label,
        icon: Icons.lock_outline,
        obscure: _hidden,
        validator: widget.validator ?? (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
        action: widget.action,
        onSubmitted: widget.onSubmitted,
        suffix: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                    Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

/// Compact dropdown used for list filters. A null value means "All".
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelOf,
    this.allLabel,
  });
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelOf;
  final String? allLabel;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerLow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isExpanded: true,
          hint: Text(label),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(allLabel ?? 'All $label')),
            ...items.map((e) => DropdownMenuItem<T?>(
                  value: e,
                  child: Text(labelOf == null ? '$e' : labelOf!(e), overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Dropdown form field that requires a selection.
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelOf,
    this.icon,
    this.validator,
  });
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelOf;
  final IconData? icon;
  final String? Function(T?)? validator;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        validator: validator ?? (v) => v == null ? 'Please select $label' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(labelOf == null ? '$e' : labelOf!(e), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      );
}

// ------------------------------------------------------------------- avatar
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photoPath, this.radius = 24, this.heroTag});
  final String name;
  final String? photoPath;
  final double radius;
  final String? heroTag;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    File? file;
    if (photoPath != null && photoPath!.isNotEmpty && File(photoPath!).existsSync()) {
      file = File(photoPath!);
    }
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: file == null ? null : FileImage(file),
      child: file == null
          ? Text(initials(name),
              style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.7))
          : null,
    );
    return heroTag == null ? avatar : Hero(tag: heroTag!, child: avatar);
  }
}
