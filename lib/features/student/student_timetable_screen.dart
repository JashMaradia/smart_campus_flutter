import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/cards.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';

class StudentTimetableScreen extends StatefulWidget {
  const StudentTimetableScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen> {
  late Future<List<TimetableEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TimetableEntry>> _load() {
    final student = context.read<AuthProvider>().student;
    if (student == null) return Future.value([]);
    return context
        .read<CampusRepository>()
        .timetableForStudent(student);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final nowStr = Fmt.nowHHmm();
    return DefaultTabController(
      length: 6,
      initialIndex: (today - 1).clamp(0, 5).toInt(),
      child: PageScaffold(
        title: 'Timetable',
        embedded: widget.embedded,
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final d in kDayNames) Tab(text: d.substring(0, 3))],
        ),
        body: MaxWidth(
          width: 800,
          child: AsyncBody<List<TimetableEntry>>(
            future: _future,
            onRetry: _reload,
            builder: (context, all) => TabBarView(
              children: [
                for (var day = 1; day <= 6; day++)
                  Builder(builder: (context) {
                    final list = all.where((e) => e.day == day).toList();
                    if (list.isEmpty) {
                      return EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'No classes on ${dayName(day)}',
                        message: 'Enjoy the free day.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = list[i];
                          return TimetableTile(
                            entry: e,
                            highlight: day == today &&
                                e.start.compareTo(nowStr) <= 0 &&
                                e.end.compareTo(nowStr) > 0,
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
