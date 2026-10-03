import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:flutter/services.dart';

class _FacultyData {
  _FacultyData(this.faculty, this.courses);
  final List<Faculty> faculty;
  final List<Course> courses;
}

class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});
  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  late Future<_FacultyData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FacultyData> _load() async {
    final repo = context.read<CampusRepository>();
    return _FacultyData(await repo.faculty(), await repo.courses());
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _edit([Faculty? f]) async {
    final saved = await showDialog<bool>(
        context: context, builder: (_) => _FacultyDialog(faculty: f));
    if (saved == true && mounted) {
      showSnack(context, f == null ? 'Faculty added' : 'Faculty updated');
      _reload();
    }
  }

  Future<void> _delete(Faculty f) async {
    final ok = await confirmDialog(context,
        title: 'Delete faculty',
        message: 'Delete ${f.name}? Their courses will become unassigned.');
    if (!ok || !mounted) return;
    await context.read<CampusRepository>().deleteFaculty(f.id!);
    if (!mounted) return;
    showSnack(context, '${f.name} deleted');
    _reload();
  }

  Future<void> _assign(Faculty f, List<Course> all) async {
    final selected = all.where((c) => c.facultyId == f.id).map((c) => c.id!).toSet();
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Assign courses to ${f.name}'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in all)
                  CheckboxListTile(
                    dense: true,
                    value: selected.contains(c.id),
                    title: Text('${c.code} \u00B7 ${c.name}'),
                    subtitle: Text('${c.program} Sem ${c.semester}'
                        '${c.facultyId != null && c.facultyId != f.id ? ' \u00B7 now: ${c.facultyName}' : ''}'),
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        selected.add(c.id!);
                      } else {
                        selected.remove(c.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await context.read<CampusRepository>().assignCourses(f.id!, result);
    if (!mounted) return;
    showSnack(context, 'Courses assigned to ${f.name}');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Faculty',
      embedded: true,
      fab: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add faculty'),
      ),
      body: MaxWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchField(
                hint: 'Search faculty',
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: AsyncBody<_FacultyData>(
                future: _future,
                onRetry: _reload,
                builder: (context, d) {
                  final list = d.faculty
                      .where((f) =>
                          _query.isEmpty ||
                          f.name.toLowerCase().contains(_query) ||
                          f.department.toLowerCase().contains(_query))
                      .toList();
                  if (list.isEmpty) {
                    return const EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'No faculty found',
                        message: 'Add a faculty member to get started.');
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final f = list[i];
                        final mine = d.courses.where((c) => c.facultyId == f.id).toList();
                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  UserAvatar(name: f.name, radius: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f.name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.w700)),
                                        Text('${f.designation} \u00B7 ${f.department}',
                                            style: theme.textTheme.bodySmall),
                                        Text('${f.email} \u00B7 ${f.phone}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _edit(f);
                                      if (v == 'assign') _assign(f, d.courses);
                                      if (v == 'delete') _delete(f);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'assign', child: Text('Assign courses')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (mine.isEmpty)
                                Text('No courses assigned',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    for (final c in mine)
                                      Chip(
                                        label: Text(c.code),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _assign(f, d.courses),
                                  icon: const Icon(Icons.link, size: 18),
                                  label: const Text('Assign courses'),
                                ),
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

class _FacultyDialog extends StatefulWidget {
  const _FacultyDialog({this.faculty});
  final Faculty? faculty;
  @override
  State<_FacultyDialog> createState() => _FacultyDialogState();
}

class _FacultyDialogState extends State<_FacultyDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.faculty?.name);
  late final _email = TextEditingController(text: widget.faculty?.email);
  late final _phone = TextEditingController(text: widget.faculty?.phone);
  late final _dept = TextEditingController(text: widget.faculty?.department);
  late final _desig = TextEditingController(text: widget.faculty?.designation);

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _dept, _desig]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await context.read<CampusRepository>().saveFaculty(Faculty(
          id: widget.faculty?.id,
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          department: _dept.text.trim(),
          designation: _desig.text.trim(),
        ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.faculty == null ? 'Add faculty' : 'Edit faculty'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  AppTextField(
                      controller: _name,
                      label: 'Full name',
                      validator: (v) => Validators.required(v, 'Name')),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _email,
                      label: 'Email',
                      keyboard: TextInputType.emailAddress,
                      validator: Validators.email),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _phone,
                      label: 'Phone',
                      keyboard: TextInputType.phone,
                      maxLength: 10,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: Validators.phone),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _dept,
                      label: 'Department',
                      validator: (v) => Validators.required(v, 'Department')),
                  const SizedBox(height: 12),
                  AppTextField(
                      controller: _desig,
                      label: 'Designation',
                      validator: (v) => Validators.required(v, 'Designation')),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}
