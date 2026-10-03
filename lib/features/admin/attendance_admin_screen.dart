import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/admin/reports_screen.dart';

class AttendanceAdminScreen extends StatelessWidget {
  const AttendanceAdminScreen({super.key});
  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 2,
        child: PageScaffold(
          title: 'Attendance',
          embedded: true,
          bottom: TabBar(tabs: [
            Tab(text: 'Mark attendance'),
            Tab(text: 'Overview'),
          ]),
          body: TabBarView(children: [_MarkTab(), _OverviewTab()]),
        ),
      );
}

// --------------------------------------------------------------- mark tab
class _MarkTab extends StatefulWidget {
  const _MarkTab();
  @override
  State<_MarkTab> createState() => _MarkTabState();
}

class _MarkTabState extends State<_MarkTab> with AutomaticKeepAliveClientMixin {
  List<Course> _courses = [];
  int? _courseId;
  DateTime _date = DateTime.now();
  List<AttendanceMark>? _rows;
  Map<int, String> _status = {};
  bool _recorded = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<CampusRepository>().courses().then((c) {
      if (mounted) setState(() => _courses = c);
    });
  }

  Future<void> _loadSheet() async {
    if (_courseId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await context.read<CampusRepository>().attendanceSheet(_courseId!, _date);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _status = {for (final r in rows) r.studentPk: r.status ?? 'present'};
        _recorded = rows.any((r) => r.status != null);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<CampusRepository>().saveAttendance(_courseId!, _date, _status);
      if (!mounted) return;
      setState(() => _recorded = true);
      showSnack(context, 'Attendance saved for ${Fmt.weekdayDate(_date)}');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final present = _status.values.where((s) => s == 'present').length;
    final absent = _status.values.where((s) => s == 'absent').length;
    final late = _status.values.where((s) => s == 'late').length;
    return MaxWidth(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                SelectField<int>(
                  label: 'Course',
                  icon: Icons.menu_book_outlined,
                  value: _courseId,
                  items: _courses.map((c) => c.id!).toList(),
                  labelOf: (id) {
                    final c = _courses.firstWhere((c) => c.id == id);
                    return '${c.code} \u00B7 ${c.name} (${c.program} Sem ${c.semester})';
                  },
                  onChanged: (v) {
                    setState(() => _courseId = v);
                    _loadSheet();
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await pickDate(context, _date,
                          first: DateTime(2020), last: DateTime.now());
                      if (d != null) {
                        setState(() => _date = d);
                        _loadSheet();
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(Fmt.weekdayDate(_date)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(builder: (context) {
              if (_courseId == null) {
                return const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Choose a course',
                    message: 'Select a course and date to mark or update attendance.');
              }
              if (_loading) return const SkeletonList();
              if (_error != null) return ErrorView(message: _error!, onRetry: _loadSheet);
              final rows = _rows ?? [];
              if (rows.isEmpty) {
                return const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No students enrolled',
                    message: 'No students belong to this course\'s program and semester.');
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        StatusChip(_recorded ? 'Recorded' : 'Not recorded yet',
                            _recorded ? AppColors.success : AppColors.amber),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _status = {for (final r in rows) r.studentPk: 'present'};
                          }),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Mark all present'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        return AppCard(
                          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w600)),
                                    Text(r.code, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              SegmentedButton<String>(
                                showSelectedIcon: false,
                                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                                segments: const [
                                  ButtonSegment(value: 'present', label: Text('P')),
                                  ButtonSegment(value: 'absent', label: Text('A')),
                                  ButtonSegment(value: 'late', label: Text('L')),
                                ],
                                selected: {_status[r.studentPk] ?? 'present'},
                                onSelectionChanged: (s) =>
                                    setState(() => _status[r.studentPk] = s.first),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Present $present \u00B7 Absent $absent \u00B7 Late $late',
                              style: theme.textTheme.bodyMedium),
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- overview tab
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with AutomaticKeepAliveClientMixin {
  late Future<List<StudentAttendanceSummary>> _future;
  List<Course> _courses = [];
  String _query = '';
  String? _program;
  int? _semester;
  int? _courseId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
    context.read<CampusRepository>().courses().then((c) {
      if (mounted) setState(() => _courses = c);
    });
  }

  Future<List<StudentAttendanceSummary>> _load() =>
      context.read<CampusRepository>().attendanceOverview(
          program: _program, semester: _semester, courseId: _courseId, query: _query);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return MaxWidth(
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
                IconButton.filledTonal(
                  tooltip: 'Attendance report',
                  icon: const Icon(Icons.assessment_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReportPreviewScreen(type: ReportType.attendance))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilterDropdown<String>(
                    label: 'Programs',
                    allLabel: 'All programs',
                    value: _program,
                    items: kPrograms.keys.toList(),
                    onChanged: (v) {
                      _program = v;
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterDropdown<int>(
                    label: 'Semesters',
                    allLabel: 'All sems',
                    value: _semester,
                    items: kSemesters,
                    labelOf: (e) => 'Sem $e',
                    onChanged: (v) {
                      _semester = v;
                      _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilterDropdown<int>(
              label: 'Courses',
              allLabel: 'All courses',
              value: _courseId,
              items: _courses.map((c) => c.id!).toList(),
              labelOf: (id) {
                final c = _courses.firstWhere((c) => c.id == id);
                return '${c.code} \u00B7 ${c.name}';
              },
              onChanged: (v) {
                _courseId = v;
                _reload();
              },
            ),
          ),
          Expanded(
            child: AsyncBody<List<StudentAttendanceSummary>>(
              future: _future,
              onRetry: _reload,
              builder: (context, list) {
                if (list.isEmpty) {
                  return const EmptyState(
                      icon: Icons.person_search_outlined, title: 'No students match');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final color = s.total == 0 ? theme.colorScheme.outline : attendanceColor(s.pct);
                      return AppCard(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => StudentAttendanceHistoryScreen(
                                studentPk: s.studentPk, name: s.name))),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(fontWeight: FontWeight.w700)),
                                      Text('${s.code} \u00B7 ${s.program} Sem ${s.semester}',
                                          style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                Text(s.total == 0 ? '--' : '${s.pct.toStringAsFixed(0)}%',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800, color: color)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: s.total == 0 ? 0 : s.pct / 100,
                                minHeight: 7,
                                color: color,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  '${s.attended} of ${s.total} classes attended'
                                  '${s.total > 0 && s.pct < AppStrings.minAttendance ? ' \u00B7 Below ${AppStrings.minAttendance}%' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant)),
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
    );
  }
}

// ------------------------------------------------ student attendance history
class _HistoryData {
  _HistoryData(this.subjects, this.history);
  final List<SubjectAttendance> subjects;
  final List<AttendanceEntry> history;
}

class StudentAttendanceHistoryScreen extends StatefulWidget {
  const StudentAttendanceHistoryScreen(
      {super.key, required this.studentPk, required this.name});
  final int studentPk;
  final String name;
  @override
  State<StudentAttendanceHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<StudentAttendanceHistoryScreen> {
  late Future<_HistoryData> _future;
  int? _courseId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HistoryData> _load() async {
    final repo = context.read<CampusRepository>();
    return _HistoryData(await repo.subjectAttendance(widget.studentPk),
        await repo.attendanceHistory(widget.studentPk, courseId: _courseId));
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: AsyncBody<_HistoryData>(
        future: _future,
        onRetry: _reload,
        builder: (context, d) => MaxWidth(
          width: 720,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (d.subjects.isEmpty)
                const EmptyState(
                    icon: Icons.fact_check_outlined, title: 'No attendance recorded yet')
              else ...[
                for (final s in d.subjects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
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
                                      fontWeight: FontWeight.w800, color: attendanceColor(s.pct))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: s.pct / 100,
                              minHeight: 7,
                              color: attendanceColor(s.pct),
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Present ${s.present} \u00B7 Late ${s.late} \u00B7 Absent ${s.absent}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                const SectionHeader('History'),
                FilterDropdown<int>(
                  label: 'Subjects',
                  allLabel: 'All subjects',
                  value: _courseId,
                  items: d.subjects.map((s) => s.courseId).toList(),
                  labelOf: (id) => d.subjects.firstWhere((s) => s.courseId == id).name,
                  onChanged: (v) {
                    _courseId = v;
                    _reload();
                  },
                ),
                const SizedBox(height: 10),
                for (final h in d.history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(h.courseName),
                    subtitle: Text(Fmt.weekdayDate(h.date)),
                    trailing: StatusChip(
                        h.status[0].toUpperCase() + h.status.substring(1),
                        h.status == 'absent'
                            ? AppColors.danger
                            : h.status == 'late'
                                ? AppColors.amber
                                : AppColors.success),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
