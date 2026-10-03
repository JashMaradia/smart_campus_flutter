import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/notification_service.dart';
import 'package:smart_campus/core/router.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/shared/notices_screen.dart';
import 'package:smart_campus/features/student/student_attendance_screen.dart';
import 'package:smart_campus/features/student/student_home.dart';
import 'package:smart_campus/features/student/student_more_screens.dart';
import 'package:smart_campus/features/student/student_timetable_screen.dart';

/// Student navigation: bottom bar on phones, side rail on tablets.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  static const _labels = ['Home', 'Timetable', 'Attendance', 'Notices', 'More'];
  static const _icons = [
    Icons.home_outlined,
    Icons.calendar_view_week_outlined,
    Icons.fact_check_outlined,
    Icons.campaign_outlined,
    Icons.more_horiz,
  ];
  static const _selectedIcons = [
    Icons.home,
    Icons.calendar_view_week,
    Icons.fact_check,
    Icons.campaign,
    Icons.more_horiz,
  ];

  @override
  void initState() {
    super.initState();
    final s = context.read<AuthProvider>().student;
    if (s != null) {
      // Creates fee, attendance and event reminders in the notification center.
      final repo = context.read<CampusRepository>();
      repo.refreshStudentAlerts(s).catchError((_) {});
      _syncDeviceReminders(repo, s);
    }
  }

  /// Schedules phone notifications for the fee due date and upcoming events.
  Future<void> _syncDeviceReminders(CampusRepository repo, Student s) async {
    try {
      final fee = await repo.feeSummary(s);
      final events = await repo.events(upcoming: true);
      await NotificationService.instance.sync(fee: fee, events: events);
    } catch (_) {}
  }

  Widget _page() {
    switch (_index) {
      case 0:
        return StudentHome(onNavigate: (i) => setState(() => _index = i));
      case 1:
        return const StudentTimetableScreen(embedded: true);
      case 2:
        return const StudentAttendanceScreen(embedded: true);
      case 3:
        return const NoticesScreen(admin: false, embedded: true);
      default:
        return const StudentMoreScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.student == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No student record is linked to this account.'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => AppRouter.logout(context), child: const Text('Logout')),
            ],
          ),
        ),
      );
    }
    final page = KeyedSubtree(key: ValueKey(_index), child: _page());
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 800) {
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (var i = 0; i < _labels.length; i++)
                      NavigationRailDestination(
                        icon: Icon(_icons[i]),
                        selectedIcon: Icon(_selectedIcons[i]),
                        label: Text(_labels[i]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        body: SafeArea(bottom: false, child: page),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (var i = 0; i < _labels.length; i++)
              NavigationDestination(
                icon: Icon(_icons[i]),
                selectedIcon: Icon(_selectedIcons[i]),
                label: _labels[i],
              ),
          ],
        ),
      );
    });
  }
}
