import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/export_service.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

Color feeStatusColor(String status) {
  switch (status) {
    case 'Paid':
      return AppColors.success;
    case 'Partial':
      return AppColors.amber;
    default:
      return AppColors.danger;
  }
}

class _FeeData {
  _FeeData(this.summary, this.payments);
  final FeeSummary summary;
  final List<Payment> payments;
}

/// Fee summary + payment history. Admins can also record payments.
class FeeDetailView extends StatefulWidget {
  const FeeDetailView({super.key, required this.student, required this.admin});
  final Student student;
  final bool admin;
  @override
  State<FeeDetailView> createState() => _FeeDetailViewState();
}

class _FeeDetailViewState extends State<FeeDetailView> {
  late Future<_FeeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FeeData> _load() async {
    final repo = context.read<CampusRepository>();
    return _FeeData(await repo.feeSummary(widget.student), await repo.payments(widget.student.id!));
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _record(FeeSummary f) async {
    final amount = TextEditingController(text: '${f.pending}');
    String method = kPaymentMethods.first;
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record payment'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                AppTextField(
                  controller: amount,
                  label: 'Amount (max ${Fmt.rupees(f.pending)})',
                  icon: Icons.currency_rupee,
                  keyboard: TextInputType.number,
                  validator: (v) {
                    final base = Validators.positiveInt(v, 'Amount');
                    if (base != null) return base;
                    return int.parse(v!.trim()) > f.pending
                        ? 'Amount exceeds the pending fees'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                SelectField<String>(
                  label: 'Payment method',
                  value: method,
                  items: kPaymentMethods,
                  onChanged: (v) => setLocal(() => method = v ?? method),
                ),
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
      ),
    );
    final value = int.tryParse(amount.text.trim());
    amount.dispose();
    if (ok != true || value == null || !mounted) return;
    final payment = await context
        .read<CampusRepository>()
        .recordPayment(widget.student.id!, value, method);
    if (!mounted) return;
    showSnack(context, 'Payment recorded. Receipt ${payment.receiptNo}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AsyncBody<_FeeData>(
      future: _future,
      onRetry: _reload,
      builder: (context, d) {
        final f = d.summary;
        final frac = f.total == 0 ? 0.0 : (f.paid / f.total).clamp(0.0, 1.0).toDouble();
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: MaxWidth(
            width: 720,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total fees',
                                    style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8))),
                                Text(Fmt.rupees(f.total),
                                    style: TextStyle(
                                        color: scheme.onPrimary,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Text(f.status == 'Due' ? 'Due' : f.status,
                                style: TextStyle(
                                    color: feeStatusColor(f.status),
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 9,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _amount(scheme, 'Paid', Fmt.rupees(f.paid), CrossAxisAlignment.start),
                          _amount(scheme, 'Pending', Fmt.rupees(f.pending), CrossAxisAlignment.end),
                        ],
                      ),
                      if (f.dueDate != null) ...[
                        const Divider(color: Colors.white24, height: 28),
                        Row(
                          children: [
                            Icon(Icons.event, size: 18, color: scheme.onPrimary),
                            const SizedBox(width: 8),
                            Text('Due date: ${Fmt.date(f.dueDate!)}',
                                style: TextStyle(color: scheme.onPrimary)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (f.total == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: AppCard(
                        child: Text(
                            'No fee structure is defined for this program and semester yet.')),
                  ),
                if (widget.admin && f.pending > 0) ...[
                  const SizedBox(height: 14),
                  PrimaryButton(
                      label: 'Record payment', icon: Icons.add_card, onPressed: () => _record(f)),
                ],
                const SectionHeader('Payment history'),
                if (d.payments.isEmpty)
                  const AppCard(child: Text('No payments recorded yet.'))
                else
                  for (final p in d.payments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.success.withValues(alpha: 0.15),
                              child: const Icon(Icons.check, color: AppColors.success),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(Fmt.rupees(p.amount),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w800)),
                                  Text('${Fmt.date(p.paidOn)} \u00B7 ${p.method} \u00B7 ${p.receiptNo}',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Receipt ${p.receiptNo}',
                              icon: const Icon(Icons.receipt_long_outlined),
                              onPressed: () async {
                                try {
                                  await ExportService.showReceipt(
                                      student: f.student,
                                      payment: p,
                                      total: f.total,
                                      paidTotal: f.paid);
                                } catch (e) {
                                  if (mounted) {
                                    showSnack(context, 'Could not create the receipt: $e',
                                        error: true);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _amount(ColorScheme scheme, String label, String value, CrossAxisAlignment align) =>
      Column(
        crossAxisAlignment: align,
        children: [
          Text(label, style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8), fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: scheme.onPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      );
}
