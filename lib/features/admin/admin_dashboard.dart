import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/charts.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/admin/requests_admin_screen.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';

class _DashData {
  _DashData(this.stats, this.activities);
  final AdminStats stats;
  final List<Activity> activities;
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.onNavigate});
  final void Function(int index) onNavigate;
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final repo = context.read<CampusRepository>();
    return _DashData(await repo.adminStats(), await repo.recentActivities(limit: 6));
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  IconData _activityIcon(String m) {
    final t = m.toLowerCase();
    if (t.contains('notice')) return Icons.campaign_outlined;
    if (t.contains('attendance')) return Icons.fact_check_outlined;
    if (t.contains('fee') || t.contains('payment')) return Icons.payments_outlined;
    if (t.contains('event')) return Icons.event_outlined;
    if (t.contains('student')) return Icons.person_add_alt_outlined;
    if (t.contains('timetable')) return Icons.calendar_view_week_outlined;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody<_DashData>(
      future: _future,
      onRetry: _reload,
      builder: (context, d) {
        final s = d.stats;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final user = context.watch<AuthProvider>().user;
        final total = s.feesCollected + s.feesPending;
        final collected = total == 0 ? 0.0 : s.feesCollected / total;

        Widget chartCard(String title, Widget child, {String? sub}) => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (sub != null)
                        Text(sub,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            );

        final trend = chartCard(
          'Attendance trend',
          s.attendanceTrend.isEmpty
              ? const SizedBox(height: 120, child: Center(child: Text('No attendance yet')))
              : LineChart(
                  values: s.attendanceTrend,
                  labels: List.generate(s.attendanceTrend.length, (i) => 'W${i + 1}')),
          sub: 'Weekly %',
        );
        final perProgram = chartCard(
          'Students per course',
          BarChart(
            values: s.studentsPerProgram.values.map((e) => e.toDouble()).toList(),
            labels: s.studentsPerProgram.keys.map((e) => e.replaceFirst('B.Tech ', '')).toList(),
          ),
        );
        final fees = chartCard(
          'Fees collected vs pending',
          Row(
            children: [
              Ring(
                fraction: collected,
                centerText: '${(collected * 100).round()}%',
                subText: 'collected',
                size: 130,
                color: AppColors.teal,
                trackColor: const Color(0xFFFDE68A),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legend(context, AppColors.teal, 'Collected', Fmt.rupees(s.feesCollected)),
                    const SizedBox(height: 14),
                    _legend(context, const Color(0xFFFDE68A), 'Pending', Fmt.rupees(s.feesPending)),
                  ],
                ),
              ),
            ],
          ),
        );

        return RefreshIndicator(
          onRefresh: _reload,
          child: MaxWidth(
            width: 1100,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(name: user?.name ?? 'Admin', radius: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back,',
                                style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8))),
                            Text(user?.name ?? 'Admin',
                                style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800)),
                            Text('Campus Administrator \u00B7 ${Fmt.weekdayDate(DateTime.now())}',
                                style: TextStyle(
                                    color: scheme.onPrimary.withValues(alpha: 0.8), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 700 ? 3 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: cols == 3 ? 1.7 : 1.2,
                    children: [
                      StatCard(
                          icon: Icons.groups_outlined,
                          value: '${s.students}',
                          label: 'Total students',
                          color: AppColors.primary,
                          onTap: () => widget.onNavigate(1)),
                      StatCard(
                          icon: Icons.badge_outlined,
                          value: '${s.faculty}',
                          label: 'Total faculty',
                          color: AppColors.teal,
                          onTap: () => widget.onNavigate(2)),
                      StatCard(
                          icon: Icons.menu_book_outlined,
                          value: '${s.courses}',
                          label: 'Total courses',
                          color: AppColors.violet,
                          onTap: () => widget.onNavigate(4)),
                      StatCard(
                          icon: Icons.fact_check_outlined,
                          value: '${s.attendancePct.toStringAsFixed(0)}%',
                          label: 'Attendance',
                          color: AppColors.success,
                          onTap: () => widget.onNavigate(3)),
                      StatCard(
                          icon: Icons.pending_actions_outlined,
                          value: '${s.pendingRequests}',
                          label: 'Pending requests',
                          color: AppColors.amber,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const RequestsAdminScreen()));
                            _reload();
                          }),
                      StatCard(
                          icon: Icons.event_outlined,
                          value: '${s.upcomingEvents}',
                          label: 'Upcoming events',
                          color: AppColors.primary,
                          onTap: () => widget.onNavigate(7)),
                    ],
                  );
                }),
                const SectionHeader('Overview'),
                LayoutBuilder(builder: (context, c) {
                  if (c.maxWidth >= 800) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: trend),
                            const SizedBox(width: 12),
                            Expanded(child: perProgram),
                          ],
                        ),
                        const SizedBox(height: 12),
                        fees,
                      ],
                    );
                  }
                  return Column(children: [
                    trend,
                    const SizedBox(height: 12),
                    perProgram,
                    const SizedBox(height: 12),
                    fees,
                  ]);
                }),
                const SectionHeader('Recent activities'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: d.activities.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16), child: Text('No activity yet.'))
                      : Column(
                          children: [
                            for (final a in d.activities)
                              ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  child: Icon(_activityIcon(a.message),
                                      size: 20, color: scheme.onPrimaryContainer),
                                ),
                                title: Text(a.message),
                                subtitle: Text(Fmt.ago(a.createdAt)),
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
    );
  }

  Widget _legend(BuildContext context, Color color, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
