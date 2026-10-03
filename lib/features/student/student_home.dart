import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/cards.dart';
import 'package:smart_campus/core/widgets/charts.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/shared/events_screen.dart';
import 'package:smart_campus/features/shared/notices_screen.dart';
import 'package:smart_campus/features/student/student_more_screens.dart';

class _HomeData {
  _HomeData(this.today, this.subjects, this.notices, this.events, this.fee, this.unread);
  final List<TimetableEntry> today;
  final List<SubjectAttendance> subjects;
  final List<Notice> notices;
  final List<EventItem> events;
  final FeeSummary fee;
  final int unread;
}

class StudentHome extends StatefulWidget {
  const StudentHome({super.key, required this.onNavigate});
  final void Function(int index) onNavigate;
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    try {
      final repo = context.read<CampusRepository>();
      final auth = context.read<AuthProvider>();
      final s = auth.student;
      if (s == null) {
        return _HomeData([], [], [], [], const FeeSummary(student: Student(studentId: '', name: '', email: '', phone: '', department: '', program: '', semester: 1, dob: ''), total: 0, paid: 0), 0);
      }
      final all = await repo.timetableForStudent(s);
      final weekday = DateTime.now().weekday;
      final todayTt = all.where((e) => e.day == weekday).toList();
      final subs = s.id == null ? <SubjectAttendance>[] : await repo.subjectAttendance(s.id!);
      final nots = (await repo.notices(publishedOnly: true)).take(3).toList();
      final evts = (await repo.events(upcoming: true)).take(3).toList();
      final fee = await repo.feeSummary(s);
      final unread = auth.user == null ? 0 : await repo.unreadCount(auth.user!.id);
      debugPrint('StudentHome _load success: student=${s.name}, todayClasses=${todayTt.length}, subjects=${subs.length}');
      return _HomeData(todayTt, subs, nots, evts, fee, unread);
    } catch (e, st) {
      debugPrint('StudentHome _load ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().student!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AsyncBody<_HomeData>(
      future: _future,
      onRetry: _reload,
      builder: (context, d) {
        final attended = d.subjects.fold<int>(0, (a, e) => a + e.attended);
        final total = d.subjects.fold<int>(0, (a, e) => a + e.total);
        final pct = attendancePercent(attended, total);
        final low = d.subjects.where((s) => s.total > 0 && s.pct < AppStrings.minAttendance).toList();
        final nowStr = Fmt.nowHHmm();
        return RefreshIndicator(
          onRefresh: _reload,
          child: MaxWidth(
            width: 800,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                          name: student.name, photoPath: student.photoPath, radius: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello,',
                                style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8))),
                            Text(student.name,
                                style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            Text('ID ${student.studentId}',
                                style: TextStyle(
                                    color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 12)),
                            Text('${student.program} \u00B7 Semester ${student.semester}',
                                style: TextStyle(
                                    color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Notifications',
                        onPressed: () => _push(const NotificationsScreen()),
                        icon: Badge(
                          isLabelVisible: d.unread > 0,
                          label: Text('${d.unread}'),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AppCard(
                        onTap: () => widget.onNavigate(2),
                        child: Row(
                          children: [
                            Ring(
                              fraction: pct / 100,
                              centerText: total == 0 ? '--' : '${pct.toStringAsFixed(0)}%',
                              size: 78,
                              stroke: 9,
                              color: total == 0 ? scheme.outline : attendanceColor(pct),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Attendance',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        onTap: () => _push(const StudentFeesScreen()),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pending fees',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(Fmt.rupees(d.fee.pending),
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.fee.pending == 0
                                  ? 'All paid'
                                  : (d.fee.dueDate == null
                                      ? ''
                                      : 'Due ${Fmt.date(d.fee.dueDate!)}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: d.fee.pending == 0 ? AppColors.success : AppColors.amber,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
                if (low.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Low attendance in ${low.map((e) => '${e.name} (${e.pct.toStringAsFixed(0)}%)').join(', ')}. '
                            'You need ${AppStrings.minAttendance}% to stay eligible for exams.',
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SectionHeader("Today's timetable",
                    actionLabel: 'View all', onAction: () => widget.onNavigate(1)),
                if (d.today.isEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.weekend_outlined, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('No classes today (${dayName(DateTime.now().weekday)}).')),
                      ],
                    ),
                  )
                else
                  for (final e in d.today)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TimetableTile(
                        entry: e,
                        highlight: e.start.compareTo(nowStr) <= 0 && e.end.compareTo(nowStr) > 0,
                      ),
                    ),
                SectionHeader('Latest notices',
                    actionLabel: 'View all', onAction: () => widget.onNavigate(3)),
                if (d.notices.isEmpty)
                  const AppCard(child: Text('No notices yet.'))
                else
                  for (final n in d.notices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NoticeCard(
                        notice: n,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: n))),
                      ),
                    ),
                SectionHeader('Upcoming events',
                    actionLabel: 'View all',
                    onAction: () => _push(const EventsScreen(admin: false))),
                if (d.events.isEmpty)
                  const AppCard(child: Text('No upcoming events.'))
                else
                  for (final e in d.events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EventCard(
                        event: e,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => EventDetailScreen(event: e))),
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
}
