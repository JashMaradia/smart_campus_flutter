import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/export_service.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

class _ReportInfo {
  const _ReportInfo(this.type, this.title, this.subtitle, this.icon, this.color);
  final ReportType type;
  final String title, subtitle;
  final IconData icon;
  final Color color;
}

const _reports = [
  _ReportInfo(ReportType.attendance, 'Student attendance',
      'Attended classes and percentage per student', Icons.fact_check_outlined, AppColors.success),
  _ReportInfo(ReportType.fees, 'Fees', 'Total, paid and pending fees with status',
      Icons.payments_outlined, AppColors.amber),
  _ReportInfo(ReportType.courses, 'Courses', 'Courses, faculty, enrolment and attendance',
      Icons.menu_book_outlined, AppColors.violet),
  _ReportInfo(ReportType.performance, 'Student performance',
      'Exam scores, percentage and grade', Icons.school_outlined, AppColors.primary),
  _ReportInfo(ReportType.faculty, 'Faculty', 'Faculty workload and assigned courses',
      Icons.badge_outlined, AppColors.teal),
];

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Reports',
      embedded: true,
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Choose a report to preview, then download it as PDF or CSV.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            for (final r in _reports)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ReportPreviewScreen(type: r.type))),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: r.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(r.icon, color: r.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(r.subtitle, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({super.key, required this.type});
  final ReportType type;
  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  String? _program;
  int? _semester;
  late Future<ReportData> _future;

  bool get _filterable => widget.type != ReportType.faculty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ReportData> _load() => context
      .read<CampusRepository>()
      .report(widget.type, program: _program, semester: _semester);

  void _reload() => setState(() => _future = _load());

  String get _subtitle => [
        if (_program != null) _program!,
        if (_semester != null) 'Semester $_semester',
      ].join(', ');

  Future<void> _export(String action) async {
    try {
      final d = await _future;
      if (action == 'pdf') await ExportService.previewReport(d, subtitle: _subtitle);
      if (action == 'share_pdf') await ExportService.shareReportPdf(d, subtitle: _subtitle);
      if (action == 'csv') await ExportService.shareReportCsv(d);
    } catch (e) {
      if (mounted) showSnack(context, 'Export failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _reports.firstWhere((r) => r.type == widget.type);
    return Scaffold(
      appBar: AppBar(
        title: Text('${info.title} report'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Download',
            icon: const Icon(Icons.download_outlined),
            onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Preview / print PDF')),
              PopupMenuItem(value: 'share_pdf', child: Text('Share PDF')),
              PopupMenuItem(value: 'csv', child: Text('Share CSV')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filterable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilterDropdown<int>(
                      label: 'Semesters',
                      allLabel: 'All semesters',
                      value: _semester,
                      items: kSemesters,
                      labelOf: (e) => 'Semester $e',
                      onChanged: (v) {
                        _semester = v;
                        _reload();
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AsyncBody<ReportData>(
              future: _future,
              onRetry: _reload,
              builder: (context, d) {
                if (d.rows.isEmpty) {
                  return const EmptyState(
                      icon: Icons.table_chart_outlined,
                      title: 'No records',
                      message: 'Nothing matches the selected filters.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text('${d.rows.length} records',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 48,
                            columnSpacing: 22,
                            columns: [
                              for (final c in d.columns)
                                DataColumn(
                                    label: Text(c,
                                        style: const TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: [
                              for (final r in d.rows)
                                DataRow(cells: [for (final v in r) DataCell(Text(v))]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
