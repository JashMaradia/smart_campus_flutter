import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/widgets/cards.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

class TimetableAdminScreen extends StatefulWidget {
  const TimetableAdminScreen({super.key});
  @override
  State<TimetableAdminScreen> createState() => _TimetableAdminScreenState();
}

class _TimetableAdminScreenState extends State<TimetableAdminScreen> {
  String _program = kPrograms.keys.first;
  int _semester = 3;
  late Future<List<TimetableEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TimetableEntry>> _load() => context
      .read<CampusRepository>()
      .timetable(program: _program, semester: _semester);

  void _reload() => setState(() => _future = _load());

  Future<void> _openForm([TimetableEntry? e]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => TimetableFormScreen(entry: e, program: _program, semester: _semester)));
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(TimetableEntry e) async {
    final ok = await confirmDialog(context,
        title: 'Delete timetable entry',
        message: 'Remove ${e.courseName} on ${dayName(e.day)} at ${Fmt.time12(e.start)}?');
    if (!ok || !mounted) return;
    await context.read<CampusRepository>().deleteTimetable(e.id!);
    if (!mounted) return;
    showSnack(context, 'Timetable entry deleted');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 5).toInt();
    return DefaultTabController(
      length: 6,
      initialIndex: todayIndex,
      child: PageScaffold(
        title: 'Timetable',
        embedded: true,
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final d in kDayNames) Tab(text: d.substring(0, 3))],
        ),
        fab: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add class'),
        ),
        body: MaxWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _program,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Class / Program',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          for (final p in kPrograms.keys)
                            DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: (v) {
                          _program = v ?? _program;
                          _reload();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<int>(
                        initialValue: _semester,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Semester',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          for (final s in kSemesters) DropdownMenuItem(value: s, child: Text('Sem $s'))
                        ],
                        onChanged: (v) {
                          _semester = v ?? _semester;
                          _reload();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncBody<List<TimetableEntry>>(
                  future: _future,
                  onRetry: _reload,
                  builder: (context, all) {
                    return TabBarView(
                      children: [
                        for (var day = 1; day <= 6; day++)
                          Builder(builder: (context) {
                            final list = all.where((e) => e.day == day).toList();
                            if (list.isEmpty) {
                              return EmptyState(
                                icon: Icons.event_busy_outlined,
                                title: 'No classes on ${dayName(day)}',
                                message: 'Tap "Add class" to schedule one for $_program Sem $_semester.',
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final e = list[i];
                                return TimetableTile(
                                  entry: e,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit class',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _openForm(e),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete class',
                                        icon: Icon(Icons.delete_outline,
                                            color: Theme.of(context).colorScheme.error),
                                        onPressed: () => _delete(e),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimetableFormScreen extends StatefulWidget {
  const TimetableFormScreen({super.key, this.entry, required this.program, required this.semester});
  final TimetableEntry? entry;
  final String program;
  final int semester;
  @override
  State<TimetableFormScreen> createState() => _TimetableFormScreenState();
}

class _TimetableFormScreenState extends State<TimetableFormScreen> {
  final _form = GlobalKey<FormState>();
  late String _program = widget.entry?.program.isNotEmpty == true ? widget.entry!.program : widget.program;
  late int _semester = (widget.entry?.semester ?? 0) > 0 ? widget.entry!.semester : widget.semester;
  late int? _courseId = widget.entry?.courseId;
  late int _day = widget.entry?.day ?? 1;
  late String _start = widget.entry?.start ?? '09:00';
  late String _end = widget.entry?.end ?? '10:00';
  late int? _facultyId = widget.entry?.facultyId;
  late final _room = TextEditingController(text: widget.entry?.room);
  List<Course> _courses = [];
  List<Faculty> _faculty = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    final repo = context.read<CampusRepository>();
    final courses = await repo.courses(program: _program, semester: _semester);
    final faculty = await repo.faculty();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _faculty = faculty;
      if (!courses.any((c) => c.id == _courseId)) _courseId = null;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final err = await context.read<CampusRepository>().saveTimetable(TimetableEntry(
            id: widget.entry?.id,
            courseId: _courseId!,
            facultyId: _facultyId,
            day: _day,
            start: _start,
            end: _end,
            room: _room.text,
          ));
      if (!mounted) return;
      if (err != null) {
        setState(() => _error = err);
      } else {
        showSnack(context, widget.entry == null ? 'Class added' : 'Class updated');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _timeField(String label, String value, ValueChanged<String> onPicked) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final t = await pickTime(context, value);
        if (t != null) onPicked(t);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(Fmt.time12(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry == null ? 'Add class' : 'Edit class')),
      body: MaxWidth(
        width: 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectField<String>(
                  label: 'Program',
                  icon: Icons.school_outlined,
                  value: _program,
                  items: kPrograms.keys.toList(),
                  onChanged: (v) {
                    setState(() => _program = v ?? _program);
                    _loadLists();
                  },
                ),
                const SizedBox(height: 14),
                SelectField<int>(
                  label: 'Semester',
                  icon: Icons.layers_outlined,
                  value: _semester,
                  items: kSemesters,
                  labelOf: (e) => 'Semester $e',
                  onChanged: (v) {
                    setState(() => _semester = v ?? _semester);
                    _loadLists();
                  },
                ),
                const SizedBox(height: 14),
                SelectField<int>(
                  label: 'Course',
                  icon: Icons.menu_book_outlined,
                  value: _courseId,
                  items: _courses.map((c) => c.id!).toList(),
                  labelOf: (id) {
                    final c = _courses.firstWhere((c) => c.id == id);
                    return '${c.code} \u00B7 ${c.name}';
                  },
                  onChanged: (v) {
                    setState(() {
                      _courseId = v;
                      final c = _courses.where((c) => c.id == v);
                      if (c.isNotEmpty) _facultyId = c.first.facultyId;
                    });
                  },
                ),
                if (_courses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 6),
                    child: Text('No courses exist for this program and semester yet.',
                        style: TextStyle(color: scheme.error)),
                  ),
                const SizedBox(height: 14),
                SelectField<int>(
                  label: 'Day',
                  icon: Icons.today_outlined,
                  value: _day,
                  items: const [1, 2, 3, 4, 5, 6],
                  labelOf: dayName,
                  onChanged: (v) => setState(() => _day = v ?? _day),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _timeField('Start', _start, (v) => setState(() => _start = v))),
                    const SizedBox(width: 12),
                    Expanded(child: _timeField('End', _end, (v) => setState(() => _end = v))),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _room,
                  label: 'Room / Classroom',
                  icon: Icons.meeting_room_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Room is required' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: _faculty.any((f) => f.id == _facultyId) ? _facultyId : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Not assigned')),
                    ..._faculty.map((f) => DropdownMenuItem<int?>(
                        value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _facultyId = v),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                    label: widget.entry == null ? 'Add class' : 'Save changes',
                    icon: Icons.check,
                    loading: _saving,
                    onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
