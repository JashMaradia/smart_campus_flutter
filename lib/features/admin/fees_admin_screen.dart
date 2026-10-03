import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/shared/fee_view.dart';

class FeesAdminScreen extends StatefulWidget {
  const FeesAdminScreen({super.key});
  @override
  State<FeesAdminScreen> createState() => _FeesAdminScreenState();
}

class _FeesAdminScreenState extends State<FeesAdminScreen> {
  late Future<List<FeeSummary>> _future;
  String _query = '';
  String? _status;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FeeSummary>> _load() =>
      context.read<CampusRepository>().allFeeSummaries(query: _query, status: _status);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Fees',
      embedded: true,
      body: MaxWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SearchField(
                      hint: 'Search student',
                      onChanged: (v) {
                        _query = v;
                        _reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const FeeStructureScreen()));
                      if (mounted) _reload();
                    },
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Structure'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in const [null, 'Paid', 'Partial', 'Due'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s ?? 'All'),
                          selected: _status == s,
                          onSelected: (_) {
                            _status = s;
                            _reload();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AsyncBody<List<FeeSummary>>(
                future: _future,
                onRetry: _reload,
                builder: (context, list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                        icon: Icons.payments_outlined, title: 'No fee records match');
                  }
                  final collected = list.fold<int>(0, (a, f) => a + f.paid);
                  final pending = list.fold<int>(0, (a, f) => a + f.pending);
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                    icon: Icons.account_balance_wallet_outlined,
                                    value: Fmt.rupees(collected),
                                    label: 'Collected',
                                    color: AppColors.success),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                    icon: Icons.hourglass_bottom,
                                    value: Fmt.rupees(pending),
                                    label: 'Pending',
                                    color: AppColors.amber),
                              ),
                            ],
                          );
                        }
                        final f = list[i - 1];
                        final frac = f.total == 0 ? 0.0 : (f.paid / f.total).clamp(0.0, 1.0).toDouble();
                        return AppCard(
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => FeeStudentScreen(student: f.student)));
                            if (mounted) _reload();
                          },
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f.student.name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.w700)),
                                        Text(
                                            '${f.student.studentId} \u00B7 ${f.student.program} Sem ${f.student.semester}',
                                            style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  StatusChip(f.status, feeStatusColor(f.status)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  minHeight: 7,
                                  color: feeStatusColor(f.status),
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('Paid ${Fmt.rupees(f.paid)}', style: theme.textTheme.bodySmall),
                                  const Spacer(),
                                  Text('Pending ${Fmt.rupees(f.pending)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeeStudentScreen extends StatelessWidget {
  const FeeStudentScreen({super.key, required this.student});
  final Student student;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(student.name)),
        body: FeeDetailView(student: student, admin: true),
      );
}

// ------------------------------------------------------------ fee structure
class FeeStructureScreen extends StatefulWidget {
  const FeeStructureScreen({super.key});
  @override
  State<FeeStructureScreen> createState() => _FeeStructureScreenState();
}

class _FeeStructureScreenState extends State<FeeStructureScreen> {
  late Future<List<FeeStructure>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<CampusRepository>().feeStructures();
  }

  void _reload() =>
      setState(() => _future = context.read<CampusRepository>().feeStructures());

  Future<void> _edit([FeeStructure? f]) async {
    final form = GlobalKey<FormState>();
    final amount = TextEditingController(text: f?.totalAmount.toString());
    String? program = f?.program;
    int? semester = f?.semester;
    DateTime due = f?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(f == null ? 'Add fee structure' : 'Edit fee structure'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  SelectField<String>(
                    label: 'Program',
                    value: program,
                    items: kPrograms.keys.toList(),
                    onChanged: f == null ? (v) => setLocal(() => program = v) : (_) {},
                  ),
                  const SizedBox(height: 12),
                  SelectField<int>(
                    label: 'Semester',
                    value: semester,
                    items: kSemesters,
                    labelOf: (e) => 'Semester $e',
                    onChanged: f == null ? (v) => setLocal(() => semester = v) : (_) {},
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: amount,
                    label: 'Total fees (Rs)',
                    keyboard: TextInputType.number,
                    validator: (v) => Validators.positiveInt(v, 'Total fees'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await pickDate(ctx, due,
                          first: DateTime(2020), last: DateTime(2100));
                      if (d != null) setLocal(() => due = d);
                    },
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('Due date: ${Fmt.date(due)}'),
                  ),
                ],
              ),
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
    final total = int.tryParse(amount.text.trim());
    amount.dispose();
    if (ok != true || total == null || program == null || semester == null || !mounted) return;
    await context.read<CampusRepository>().saveFeeStructure(FeeStructure(
        program: program!, semester: semester!, totalAmount: total, dueDate: due));
    if (!mounted) return;
    showSnack(context, 'Fee structure saved');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Fee structure')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: AsyncBody<List<FeeStructure>>(
        future: _future,
        onRetry: _reload,
        builder: (context, list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.payments_outlined, title: 'No fee structures yet');
          }
          return MaxWidth(
            width: 720,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final f = list[i];
                return AppCard(
                  onTap: () => _edit(f),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${f.program} \u00B7 Semester ${f.semester}',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text('Due ${Fmt.date(f.dueDate)}', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Text(Fmt.rupees(f.totalAmount),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
