import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/router.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/admin/courses_admin_screen.dart';
import 'package:smart_campus/features/admin/requests_admin_screen.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/shared/events_screen.dart';
import 'package:smart_campus/features/shared/fee_view.dart';
import 'package:smart_campus/features/shared/notices_screen.dart';
import 'package:smart_campus/features/shared/settings_screen.dart';
import 'package:smart_campus/features/student/student_attendance_screen.dart';
import 'package:smart_campus/features/student/student_profile_screen.dart';
import 'package:smart_campus/features/student/student_timetable_screen.dart';

// ------------------------------------------------------------------- More
class StudentMoreScreen extends StatefulWidget {
  const StudentMoreScreen({super.key});
  @override
  State<StudentMoreScreen> createState() => _StudentMoreScreenState();
}

class _StudentMoreScreenState extends State<StudentMoreScreen> {
  late Future<int> _unread;

  @override
  void initState() {
    super.initState();
    _unread = _load();
  }

  Future<int> _load() =>
      context.read<CampusRepository>().unreadCount(context.read<AuthProvider>().user!.id);

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() => _unread = _load());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final student = context.watch<AuthProvider>().student!;
    Widget tile(IconData icon, String title, VoidCallback onTap, {Widget? trailing, Color? color}) =>
        ListTile(
          leading: Icon(icon, color: color),
          title: Text(title, style: TextStyle(color: color)),
          trailing: trailing ?? const Icon(Icons.chevron_right),
          onTap: onTap,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('More'), automaticallyImplyLeading: false),
      body: MaxWidth(
        width: 640,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              onTap: () => _push(const StudentProfileScreen()),
              child: Row(
                children: [
                  UserAvatar(name: student.name, photoPath: student.photoPath, radius: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text('${student.studentId} \u00B7 ${student.program}'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  tile(Icons.menu_book_outlined, 'Courses', () => _push(const StudentCoursesScreen())),
                  const Divider(height: 1),
                  tile(Icons.event_outlined, 'Events', () => _push(const EventsScreen(admin: false))),
                  const Divider(height: 1),
                  tile(Icons.payments_outlined, 'Fees', () => _push(const StudentFeesScreen())),
                  const Divider(height: 1),
                  FutureBuilder<int>(
                    future: _unread,
                    builder: (context, snap) {
                      final n = snap.data ?? 0;
                      return tile(
                        Icons.notifications_outlined,
                        'Notifications',
                        () => _push(const NotificationsScreen()),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (n > 0)
                              Badge(label: Text('$n')),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  tile(Icons.assignment_outlined, 'My requests',
                      () => _push(const StudentRequestsScreen())),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  tile(Icons.person_outline, 'My profile',
                      () => _push(const StudentProfileScreen())),
                  const Divider(height: 1),
                  tile(Icons.settings_outlined, 'Settings',
                      () => _push(const SettingsScreen(admin: false))),
                  const Divider(height: 1),
                  tile(Icons.logout, 'Logout', () => AppRouter.logout(context),
                      color: scheme.error, trailing: const SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Courses
class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});
  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  late Future<List<Course>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Course>> _load() => context
      .read<CampusRepository>()
      .coursesForStudent(context.read<AuthProvider>().student!);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My courses')),
      body: AsyncBody<List<Course>>(
        future: _future,
        onRetry: _reload,
        builder: (context, list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No courses yet',
                message: 'Courses for your program and semester will appear here.');
          }
          return MaxWidth(
            width: 720,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = list[i];
                return AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseDetailScreen(course: c, canEdit: false))),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(c.code,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(c.facultyName ?? 'Faculty not assigned',
                                style: theme.textTheme.bodySmall),
                            Text('Semester ${c.semester} \u00B7 ${c.credits} credits',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
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

// ------------------------------------------------------------------- Fees
class StudentFeesScreen extends StatelessWidget {
  const StudentFeesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().student!;
    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: FeeDetailView(student: student, admin: false),
    );
  }
}

// ---------------------------------------------------------- Notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() => context
      .read<CampusRepository>()
      .notifications(context.read<AuthProvider>().user!.id);

  void _reload() => setState(() => _future = _load());

  IconData _icon(String type) {
    switch (type) {
      case 'notice':
        return Icons.campaign_outlined;
      case 'timetable':
        return Icons.calendar_view_week_outlined;
      case 'attendance':
        return Icons.fact_check_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'fee':
        return Icons.payments_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'attendance':
        return AppColors.danger;
      case 'fee':
        return AppColors.amber;
      case 'event':
        return AppColors.teal;
      default:
        return AppColors.primary;
    }
  }

  Widget? _target(String type) {
    switch (type) {
      case 'notice':
        return const NoticesScreen(admin: false);
      case 'timetable':
        return const StudentTimetableScreen();
      case 'attendance':
        return const StudentAttendanceScreen();
      case 'event':
        return const EventsScreen(admin: false);
      case 'fee':
        return const StudentFeesScreen();
      case 'request':
        return const StudentRequestsScreen();
    }
    return null;
  }

  Future<void> _open(AppNotification n) async {
    await context.read<CampusRepository>().markRead(n.id);
    if (!mounted) return;
    final target = _target(n.type);
    if (target != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await context
                  .read<CampusRepository>()
                  .markAllRead(context.read<AuthProvider>().user!.id);
              if (mounted) _reload();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: AsyncBody<List<AppNotification>>(
        future: _future,
        onRetry: _reload,
        builder: (context, list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications',
                message: 'New notices, timetable changes, alerts and reminders appear here.');
          }
          return MaxWidth(
            width: 720,
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final n = list[i];
                  final color = _color(n.type);
                  return AppCard(
                    onTap: () => _open(n),
                    color: n.isRead ? null : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(_icon(n.type), color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(n.message, style: theme.textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text(Fmt.ago(n.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                                color: theme.colorScheme.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------- Requests
class StudentRequestsScreen extends StatefulWidget {
  const StudentRequestsScreen({super.key});
  @override
  State<StudentRequestsScreen> createState() => _StudentRequestsScreenState();
}

class _StudentRequestsScreenState extends State<StudentRequestsScreen> {
  late Future<List<CampusRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CampusRequest>> _load() => context
      .read<CampusRepository>()
      .requests(studentId: context.read<AuthProvider>().student!.id);

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    final form = GlobalKey<FormState>();
    final details = TextEditingController();
    String type = kRequestTypes.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New request'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                SelectField<String>(
                  label: 'Request type',
                  value: type,
                  items: kRequestTypes,
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: details,
                  label: 'Details',
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please add some details' : null,
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
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    final text = details.text.trim();
    details.dispose();
    if (ok != true || !mounted) return;
    await context
        .read<CampusRepository>()
        .createRequest(context.read<AuthProvider>().student!.id!, type, text);
    if (!mounted) return;
    showSnack(context, 'Request submitted');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: AsyncBody<List<CampusRequest>>(
        future: _future,
        onRetry: _reload,
        builder: (context, list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No requests yet',
                message: 'Request certificates, ID cards, leave or fee concessions here.');
          }
          return MaxWidth(
            width: 720,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
                      Text(r.details),
                      const SizedBox(height: 4),
                      Text(Fmt.ago(r.createdAt), style: theme.textTheme.bodySmall),
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
