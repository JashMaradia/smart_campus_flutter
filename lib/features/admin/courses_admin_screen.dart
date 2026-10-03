import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

class CoursesAdminScreen extends StatefulWidget {
  const CoursesAdminScreen({super.key});
  @override
  State<CoursesAdminScreen> createState() => _CoursesAdminScreenState();
}

class _CoursesAdminScreenState extends State<CoursesAdminScreen> {
  late Future<List<Course>> _future;
  String? _program;
  int? _semester;

  @override
  void initState() {
    super.initState();
    _future = context.read<CampusRepository>().courses();
  }

  void _reload() => setState(() => _future =
      context.read<CampusRepository>().courses(program: _program, semester: _semester));

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  Future<void> _delete(Course c) async {
    final ok = await confirmDialog(context,
        title: 'Delete course',
        message: 'Delete ${c.code} ${c.name}? Its timetable and attendance records will be removed.');
    if (!ok || !mounted) return;
    await context.read<CampusRepository>().deleteCourse(c.id!);
    if (!mounted) return;
    showSnack(context, '${c.name} deleted');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Courses',
      embedded: true,
      fab: FloatingActionButton.extended(
        onPressed: () => _open(const CourseFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Add course'),
      ),
      body: MaxWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              child: AsyncBody<List<Course>>(
                future: _future,
                onRetry: _reload,
                builder: (context, list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No courses found',
                        message: 'Add a course or change the filters.');
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return AppCard(
                          onTap: () => _open(CourseDetailScreen(course: c, canEdit: true)),
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
                                    Text('${c.program} \u00B7 Sem ${c.semester} \u00B7 ${c.credits} credits',
                                        style: theme.textTheme.bodySmall),
                                    Text(c.facultyName ?? 'No faculty assigned',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _open(CourseFormScreen(course: c));
                                  if (v == 'delete') _delete(c);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
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
      ),
    );
  }
}

class CourseFormScreen extends StatefulWidget {
  const CourseFormScreen({super.key, this.course});
  final Course? course;
  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.course?.code);
  late final _name = TextEditingController(text: widget.course?.name);
  late final _credits = TextEditingController(text: widget.course?.credits.toString());
  late final _desc = TextEditingController(text: widget.course?.description);
  late String? _program = widget.course?.program;
  late int? _semester = widget.course?.semester;
  late int? _facultyId = widget.course?.facultyId;
  late Future<List<Faculty>> _faculty;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _faculty = context.read<CampusRepository>().faculty();
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _credits, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final err = await context.read<CampusRepository>().saveCourse(Course(
            id: widget.course?.id,
            code: _code.text.trim().toUpperCase(),
            name: _name.text.trim(),
            program: _program!,
            semester: _semester!,
            credits: int.parse(_credits.text.trim()),
            facultyId: _facultyId,
            description: _desc.text.trim(),
          ));
      if (!mounted) return;
      if (err != null) {
        setState(() => _error = err);
      } else {
        showSnack(context, widget.course == null ? 'Course added' : 'Course updated');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.course == null ? 'Add course' : 'Edit course')),
      body: MaxWidth(
        width: 640,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                    controller: _code,
                    label: 'Course code',
                    icon: Icons.tag,
                    validator: (v) => Validators.required(v, 'Course code')),
                const SizedBox(height: 14),
                AppTextField(
                    controller: _name,
                    label: 'Course name',
                    icon: Icons.menu_book_outlined,
                    validator: (v) => Validators.required(v, 'Course name')),
                const SizedBox(height: 14),
                SelectField<String>(
                  label: 'Program',
                  icon: Icons.school_outlined,
                  value: _program,
                  items: kPrograms.keys.toList(),
                  onChanged: (v) => setState(() => _program = v),
                ),
                const SizedBox(height: 14),
                SelectField<int>(
                  label: 'Semester',
                  icon: Icons.layers_outlined,
                  value: _semester,
                  items: kSemesters,
                  labelOf: (e) => 'Semester $e',
                  onChanged: (v) => setState(() => _semester = v),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _credits,
                  label: 'Credits',
                  icon: Icons.stars_outlined,
                  keyboard: TextInputType.number,
                  validator: (v) => Validators.positiveInt(v, 'Credits'),
                ),
                const SizedBox(height: 14),
                FutureBuilder<List<Faculty>>(
                  future: _faculty,
                  builder: (context, snap) {
                    final list = snap.data ?? const <Faculty>[];
                    return DropdownButtonFormField<int?>(
                      initialValue: list.any((f) => f.id == _facultyId) ? _facultyId : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Assigned faculty',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Not assigned')),
                        ...list.map((f) => DropdownMenuItem<int?>(
                            value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _facultyId = v),
                    );
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                    controller: _desc,
                    label: 'Description (optional)',
                    icon: Icons.notes,
                    maxLines: 3),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                  ),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                    label: widget.course == null ? 'Add course' : 'Save changes',
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

/// Course details + materials. Used by admin (canEdit) and students (read only).
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.course, this.canEdit = false});
  final Course course;
  final bool canEdit;
  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Future<List<CourseMaterial>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<CampusRepository>().materials(widget.course.id!);
  }

  void _reload() => setState(
      () => _future = context.read<CampusRepository>().materials(widget.course.id!));

  Future<void> _addMaterial() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    final saved = await persistFile(path, 'materials');
    final title = result!.files.single.name;
    if (!mounted) return;
    await context.read<CampusRepository>().addMaterial(widget.course.id!, title, saved);
    if (!mounted) return;
    showSnack(context, 'Material added');
    _reload();
  }

  Future<void> _openFile(CourseMaterial m) async {
    final r = await OpenFilex.open(m.filePath);
    if (mounted && r.type != ResultType.done) {
      showSnack(context, 'Could not open the file: ${r.message}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c.code)),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: _addMaterial,
              icon: const Icon(Icons.upload_file),
              label: const Text('Add material'),
            )
          : null,
      body: MaxWidth(
        width: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  InfoRow('Program', c.program, icon: Icons.school_outlined),
                  InfoRow('Semester', '${c.semester}', icon: Icons.layers_outlined),
                  InfoRow('Credits', '${c.credits}', icon: Icons.stars_outlined),
                  InfoRow('Faculty', c.facultyName ?? 'Not assigned', icon: Icons.badge_outlined),
                  if (c.description.isNotEmpty) ...[
                    const Divider(),
                    Text(c.description),
                  ],
                ],
              ),
            ),
            const SectionHeader('Course materials'),
            FutureBuilder<List<CourseMaterial>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()));
                }
                final list = snap.data ?? const <CourseMaterial>[];
                if (list.isEmpty) {
                  return AppCard(
                    child: Text(
                        widget.canEdit
                            ? 'No materials yet. Tap "Add material" to upload a file.'
                            : 'No materials have been shared for this course yet.'),
                  );
                }
                return Column(
                  children: [
                    for (final m in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => _openFile(m),
                          padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                          child: Row(
                            children: [
                              const Icon(Icons.description_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('Added ${Fmt.date(m.addedOn)}',
                                        style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              if (widget.canEdit)
                                IconButton(
                                  tooltip: 'Delete material',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await context.read<CampusRepository>().deleteMaterial(m.id);
                                    _reload();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
