import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late Future<List<Student>> _future;
  String _query = '';
  String? _program;
  int? _semester;

  @override
  void initState() {
    super.initState();
    _future = context.read<CampusRepository>().students();
  }

  void _reload() {
    setState(() {
      _future = context
          .read<CampusRepository>()
          .students(query: _query, program: _program, semester: _semester);
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  Future<void> _delete(Student s) async {
    final ok = await confirmDialog(context,
        title: 'Delete student',
        message:
            'Delete ${s.name}? Their login, attendance, fees and requests will also be removed.');
    if (!ok || !mounted) return;
    await context.read<CampusRepository>().deleteStudent(s.id!);
    if (!mounted) return;
    showSnack(context, '${s.name} deleted');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Students',
      embedded: true,
      fab: FloatingActionButton.extended(
        onPressed: () => _open(const StudentFormScreen()),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add student'),
      ),
      body: MaxWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SearchField(
                hint: 'Search by name, ID or email',
                onChanged: (v) {
                  _query = v;
                  _reload();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
              child: AsyncBody<List<Student>>(
                future: _future,
                onRetry: _reload,
                builder: (context, list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No students found',
                      message: 'Try a different search or filter, or add a new student.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            child: Text('${list.length} students',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          );
                        }
                        final s = list[i - 1];
                        return AppCard(
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                          onTap: () => _open(StudentDetailScreen(studentPk: s.id!)),
                          child: Row(
                            children: [
                              UserAvatar(name: s.name, photoPath: s.photoPath, radius: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w700)),
                                    Text('${s.studentId} \u00B7 ${s.program}',
                                        style: theme.textTheme.bodySmall),
                                    Text('Semester ${s.semester} \u00B7 ${s.phone}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit ${s.name}',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _open(StudentFormScreen(student: s)),
                              ),
                              IconButton(
                                tooltip: 'Delete ${s.name}',
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                onPressed: () => _delete(s),
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

// --------------------------------------------------------------- add / edit
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.student});
  final Student? student;
  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _dobText = TextEditingController();
  String? _program;
  int? _semester;
  DateTime? _dob;
  bool _createAccount = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    if (s != null) {
      _id.text = s.studentId;
      _name.text = s.name;
      _email.text = s.email;
      _phone.text = s.phone;
      _address.text = s.address;
      _program = s.program;
      _semester = s.semester;
      _dob = s.dobDate;
      _dobText.text = Fmt.date(s.dobDate);
    }
  }

  @override
  void dispose() {
    for (final c in [_id, _name, _email, _phone, _address, _dobText]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDob() async {
    final d = await pickDate(context, _dob ?? DateTime(2004, 1, 1),
        first: DateTime(1980), last: DateTime.now());
    if (d != null) {
      setState(() {
        _dob = d;
        _dobText.text = Fmt.date(d);
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final old = widget.student;
    final s = Student(
      id: old?.id,
      userId: old?.userId,
      studentId: _id.text.trim(),
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      department: kPrograms[_program]!,
      program: _program!,
      semester: _semester!,
      photoPath: old?.photoPath,
      address: _address.text.trim(),
      dob: Fmt.dbDate(_dob!),
    );
    try {
      final err = await context
          .read<CampusRepository>()
          .saveStudent(s, createAccount: !_isEdit && _createAccount);
      if (!mounted) return;
      if (err != null) {
        setState(() => _error = err);
      } else {
        showSnack(
            context,
            _isEdit
                ? 'Student updated'
                : (_createAccount
                    ? 'Student added. Default password: ${AppStrings.defaultStudentPassword}'
                    : 'Student added. They can activate their account from the login page.'));
        Navigator.of(context).pop(true);
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit student' : 'Add student')),
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
                  controller: _id,
                  label: 'Student ID',
                  icon: Icons.badge_outlined,
                  action: TextInputAction.next,
                  validator: (v) => Validators.required(v, 'Student ID'),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  action: TextInputAction.next,
                  validator: (v) => Validators.required(v, 'Name'),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  keyboard: TextInputType.emailAddress,
                  action: TextInputAction.next,
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _phone,
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  maxLength: 10,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  action: TextInputAction.next,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 14),
                SelectField<String>(
                  label: 'Course / Program',
                  icon: Icons.menu_book_outlined,
                  value: _program,
                  items: kPrograms.keys.toList(),
                  onChanged: (v) => setState(() => _program = v),
                ),
                if (_program != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 0, 0),
                    child: Text('Department: ${kPrograms[_program]}',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
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
                  controller: _dobText,
                  label: 'Date of birth',
                  icon: Icons.cake_outlined,
                  readOnly: true,
                  onTap: _pickDob,
                  validator: (v) => _dob == null ? 'Date of birth is required' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _address,
                  label: 'Address (optional)',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Create login account'),
                    subtitle: const Text(
                        'Default password ${AppStrings.defaultStudentPassword}. If off, the student activates from the login page.'),
                    value: _createAccount,
                    onChanged: (v) => setState(() => _createAccount = v),
                  ),
                ],
                const SizedBox(height: 12),
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
                  label: _isEdit ? 'Save changes' : 'Add student',
                  icon: Icons.check,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- details
class _DetailData {
  _DetailData(this.student, this.subjects, this.fee);
  final Student student;
  final List<SubjectAttendance> subjects;
  final FeeSummary fee;
}

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentPk});
  final int studentPk;
  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final repo = context.read<CampusRepository>();
    final s = await repo.studentById(widget.studentPk);
    if (s == null) throw Exception('Student not found');
    return _DetailData(s, await repo.subjectAttendance(s.id!), await repo.feeSummary(s));
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student details'),
        actions: [
          IconButton(
            tooltip: 'Edit student',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final d = await _future;
              if (!mounted) return;
              final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => StudentFormScreen(student: d.student)));
              if (changed == true) _reload();
            },
          ),
        ],
      ),
      body: AsyncBody<_DetailData>(
        future: _future,
        onRetry: _reload,
        builder: (context, d) {
          final s = d.student;
          final attended = d.subjects.fold<int>(0, (a, e) => a + e.attended);
          final total = d.subjects.fold<int>(0, (a, e) => a + e.total);
          final pct = attendancePercent(attended, total);
          return MaxWidth(
            width: 720,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      UserAvatar(name: s.name, photoPath: s.photoPath, radius: 34),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(s.studentId, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, children: [
                              StatusChip(s.program, AppColors.primary),
                              StatusChip('Sem ${s.semester}', AppColors.teal),
                              StatusChip(s.hasAccount ? 'Login active' : 'No login yet',
                                  s.hasAccount ? AppColors.success : AppColors.amber),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Profile'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Email', s.email, icon: Icons.mail_outline),
                      InfoRow('Phone', s.phone, icon: Icons.phone_outlined),
                      InfoRow('Department', s.department, icon: Icons.apartment_outlined),
                      InfoRow('Date of birth', Fmt.date(s.dobDate), icon: Icons.cake_outlined),
                      InfoRow('Address', s.address, icon: Icons.home_outlined),
                    ],
                  ),
                ),
                const SectionHeader('Attendance'),
                AppCard(
                  child: d.subjects.isEmpty
                      ? const Text('No attendance recorded yet.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overall ${pct.toStringAsFixed(1)}% ($attended of $total classes)',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            for (final sub in d.subjects)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(sub.name)),
                                        Text('${sub.pct.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: attendanceColor(sub.pct))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: sub.pct / 100,
                                        minHeight: 8,
                                        color: attendanceColor(sub.pct),
                                        backgroundColor: scheme.surfaceContainerHighest,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                const SectionHeader('Fees'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Total', Fmt.rupees(d.fee.total)),
                      InfoRow('Paid', Fmt.rupees(d.fee.paid)),
                      InfoRow('Pending', Fmt.rupees(d.fee.pending)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                            d.fee.status,
                            d.fee.status == 'Paid'
                                ? AppColors.success
                                : d.fee.status == 'Partial'
                                    ? AppColors.amber
                                    : AppColors.danger),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
