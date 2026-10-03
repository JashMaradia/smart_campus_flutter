import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/router.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/features/admin/admin_dashboard.dart';
import 'package:smart_campus/features/admin/attendance_admin_screen.dart';
import 'package:smart_campus/features/admin/courses_admin_screen.dart';
import 'package:smart_campus/features/admin/faculty_screen.dart';
import 'package:smart_campus/features/admin/fees_admin_screen.dart';
import 'package:smart_campus/features/admin/profile_admin_screen.dart';
import 'package:smart_campus/features/admin/reports_screen.dart';
import 'package:smart_campus/features/admin/students_screen.dart';
import 'package:smart_campus/features/admin/timetable_admin_screen.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/shared/events_screen.dart';
import 'package:smart_campus/features/shared/notices_screen.dart';
import 'package:smart_campus/features/shared/settings_screen.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.build);
  final String label;
  final IconData icon;
  final Widget Function(void Function(int) go) build;
}

/// Admin navigation: drawer on phones, permanent side menu on tablets.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  late final List<_NavItem> _items = [
    _NavItem('Dashboard', Icons.dashboard_outlined, (go) => AdminDashboard(onNavigate: go)),
    _NavItem('Students', Icons.groups_outlined, (_) => const StudentsScreen()),
    _NavItem('Faculty', Icons.badge_outlined, (_) => const FacultyScreen()),
    _NavItem('Attendance', Icons.fact_check_outlined, (_) => const AttendanceAdminScreen()),
    _NavItem('Courses', Icons.menu_book_outlined, (_) => const CoursesAdminScreen()),
    _NavItem('Timetable', Icons.calendar_view_week_outlined, (_) => const TimetableAdminScreen()),
    _NavItem('Notices', Icons.campaign_outlined,
        (_) => const NoticesScreen(admin: true, embedded: true)),
    _NavItem('Events', Icons.event_outlined,
        (_) => const EventsScreen(admin: true, embedded: true)),
    _NavItem('Fees', Icons.payments_outlined, (_) => const FeesAdminScreen()),
    _NavItem('Reports', Icons.assessment_outlined, (_) => const ReportsScreen()),
    _NavItem('Profile', Icons.person_outline, (_) => const ProfileAdminScreen()),
    _NavItem('Settings', Icons.settings_outlined,
        (_) => const SettingsScreen(admin: true, embedded: true)),
  ];

  void _go(int i) => setState(() => _index = i);

  void _select(int i, bool wide) {
    setState(() => _index = i);
    if (!wide) Navigator.of(context).pop();
  }

  Widget _menu(bool wide) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().user;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Row(
              children: [
                UserAvatar(name: user?.name ?? 'Admin', radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Admin',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(user?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                for (var i = 0; i < _items.length; i++)
                  ListTile(
                    selected: i == _index,
                    selectedTileColor: scheme.primaryContainer,
                    shape: const StadiumBorder(),
                    leading: Icon(_items[i].icon),
                    title: Text(_items[i].label),
                    onTap: () => _select(i, wide),
                  ),
                const Divider(),
                ListTile(
                  shape: const StadiumBorder(),
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text('Logout', style: TextStyle(color: scheme.error)),
                  onTap: () => AppRouter.logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = _items[_index];
    final page = KeyedSubtree(key: ValueKey(_index), child: item.build(_go));
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(width: 270, child: Material(color: scheme.surfaceContainerLow, child: _menu(true))),
              const VerticalDivider(width: 1),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(title: Text(item.label)),
                  body: page,
                ),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(item.label)),
        drawer: Drawer(child: _menu(false)),
        body: page,
      );
    });
  }
}
