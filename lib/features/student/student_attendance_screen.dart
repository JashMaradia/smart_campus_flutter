import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/charts.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';

class _AttData {
  _AttData(this.subjects, this.history);
  final List<SubjectAttendance> subjects;
  final List<AttendanceEntry> history;
}

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  late Future<_AttData> _future;
  String? _subject;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AttData> _load() async {
    final repo = context.read<CampusRepository>();
    final s = context.read<AuthProvider>().student!;
    return _AttData(await repo.subjectAttendance(s.id!), await repo.attendanceHistory(s.id!));
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PageScaffold(
      title: 'Attendance',
      embedded: widget.embedded,
      body: AsyncBody<_AttData>(
        future: _future,
        onRetry: _reload,
        builder: (context, d) {
          if (d.subjects.isEmpty) {
            return const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No attendance yet',
                message: 'Your attendance will appear here once classes are marked.');
          }
          final present = d.subjects.fold<int>(0, (a, e) => a + e.attended);
          final absent = d.subjects.fold<int>(0, (a, e) => a + e.absent);
          final total = d.subjects.fold<int>(0, (a, e) => a + e.total);
          final pct = attendancePercent(present, total);
          final low = d.subjects.where((s) => s.pct < AppStrings.minAttendance).toList();
          final history = d.history
              .where((h) => _subject == null || h.courseName == _subject)
              .take(40)
              .toList();
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: MaxWidth(
              width: 800,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        Ring(
                          fraction: pct / 100,
                          centerText: '${pct.toStringAsFixed(0)}%',
                          subText: 'Overall',
                          size: 160,
                          stroke: 14,
                          color: attendanceColor(pct),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _count('Present', present, AppColors.success)),
                            const SizedBox(width: 8),
                            Expanded(child: _count('Absent', absent, AppColors.danger)),
                            const SizedBox(width: 8),
                            Expanded(child: _count('Total', total, AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  for (final s in low)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${s.name} is at ${s.pct.toStringAsFixed(0)}%. You need ${AppStrings.minAttendance}% to stay eligible for exams.',
                                style: TextStyle(color: scheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SectionHeader('Subject-wise attendance'),
                  AppCard(
                    child: Column(
                      children: [
                        for (final s in d.subjects)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: Text(s.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600))),
                                    Text('${s.pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: attendanceColor(s.pct))),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: s.pct / 100,
                                    minHeight: 8,
                                    color: attendanceColor(s.pct),
                                    backgroundColor: scheme.surfaceContainerHighest,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                    'Present ${s.present} \u00B7 Late ${s.late} \u00B7 Absent ${s.absent}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SectionHeader('Attendance chart'),
                  AppCard(
                    child: BarChart(
                      values: d.subjects.map((s) => s.pct).toList(),
                      labels: d.subjects.map((s) => s.code).toList(),
                      maxValue: 100,
                      suffix: '%',
                      colors: d.subjects.map((s) => attendanceColor(s.pct)).toList(),
                      height: 190,
                    ),
                  ),
                  const SectionHeader('Attendance history'),
                  FilterDropdown<String>(
                    label: 'Subjects',
                    allLabel: 'All subjects',
                    value: _subject,
                    items: d.subjects.map((s) => s.name).toList(),
                    onChanged: (v) => setState(() => _subject = v),
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: history.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(12), child: Text('No records.'))
                        : Column(
                            children: [
                              for (final h in history)
                                ListTile(
                                  dense: true,
                                  title: Text(h.courseName),
                                  subtitle: Text(Fmt.weekdayDate(h.date)),
                                  trailing: StatusChip(
                                    h.status[0].toUpperCase() + h.status.substring(1),
                                    h.status == 'absent'
                                        ? AppColors.danger
                                        : h.status == 'late'
                                            ? AppColors.amber
                                            : AppColors.success,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _count(String label, int value, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      );
}
