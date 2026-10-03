import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

Color requestStatusColor(String s) {
  switch (s) {
    case 'Approved':
      return AppColors.success;
    case 'Rejected':
      return AppColors.danger;
    default:
      return AppColors.amber;
  }
}

/// Student requests (certificates, leave, ...) that the admin approves or rejects.
class RequestsAdminScreen extends StatefulWidget {
  const RequestsAdminScreen({super.key});
  @override
  State<RequestsAdminScreen> createState() => _RequestsAdminScreenState();
}

class _RequestsAdminScreenState extends State<RequestsAdminScreen> {
  late Future<List<CampusRequest>> _future;
  String? _status = 'Pending';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CampusRequest>> _load() =>
      context.read<CampusRepository>().requests(status: _status);

  void _reload() => setState(() => _future = _load());

  Future<void> _decide(CampusRequest r, String status) async {
    await context.read<CampusRepository>().setRequestStatus(r.id, status);
    if (!mounted) return;
    showSnack(context, 'Request ${status.toLowerCase()}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Student requests')),
      body: MaxWidth(
        width: 720,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in const ['Pending', 'Approved', 'Rejected', null])
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
              child: AsyncBody<List<CampusRequest>>(
                future: _future,
                onRetry: _reload,
                builder: (context, list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No requests',
                        message: 'Nothing to review here.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = list[i];
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(r.type,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700)),
                                ),
                                StatusChip(r.status, requestStatusColor(r.status)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${r.studentName} (${r.studentCode}) \u00B7 ${Fmt.ago(r.createdAt)}',
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Text(r.details),
                            if (r.status == 'Pending') ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                      onPressed: () => _decide(r, 'Rejected'),
                                      child: const Text('Reject')),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                      onPressed: () => _decide(r, 'Approved'),
                                      child: const Text('Approve')),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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
