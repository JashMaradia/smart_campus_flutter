import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/cards.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';

/// Notice board. Admins manage notices (create, edit, publish, delete with undo);
/// students see published notices and an unread marker.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key, required this.admin, this.embedded = false});
  final bool admin;
  final bool embedded;
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  late Future<List<Notice>> _future;
  String _query = '';
  String? _category;
  Set<String> _read = {};

  String get _readKey => 'read_notices_${context.read<AuthProvider>().user?.id}';

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (!widget.admin) _loadRead();
  }

  Future<List<Notice>> _load() => context.read<CampusRepository>().notices(
      publishedOnly: !widget.admin, category: _category, query: _query);

  void _reload() => setState(() => _future = _load());

  Future<void> _loadRead() async {
    final key = _readKey;
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _read = (prefs.getStringList(key) ?? []).toSet());
  }

  Future<void> _markRead(Notice n) async {
    final key = _readKey;
    final prefs = await SharedPreferences.getInstance();
    _read.add('${n.id}');
    await prefs.setStringList(key, _read.toList());
    if (mounted) setState(() {});
  }

  Future<void> _openForm([Notice? n]) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => NoticeFormScreen(notice: n)));
    if (saved == true && mounted) _reload();
  }

  Future<void> _open(Notice n) async {
    if (!widget.admin) _markRead(n);
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: n)));
  }

  Future<void> _togglePublish(Notice n) async {
    await context.read<CampusRepository>().saveNotice(n.copyWith(isPublished: !n.isPublished));
    if (!mounted) return;
    showSnack(context, n.isPublished ? 'Notice moved to drafts' : 'Notice published to students');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Notices',
      embedded: widget.embedded,
      fab: widget.admin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('New notice'),
            )
          : null,
      body: MaxWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SearchField(
                hint: 'Search notices',
                onChanged: (v) {
                  _query = v;
                  _reload();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in <String?>[null, ...kNoticeCategories])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c ?? 'All'),
                          selected: _category == c,
                          onSelected: (_) {
                            setState(() {
                              _category = c;
                              _future = _load();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AsyncBody<List<Notice>>(
                future: _future,
                onRetry: _reload,
                builder: (context, list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No notices found',
                      message: widget.admin
                          ? 'Create a notice to share news with students.'
                          : 'You are all caught up.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = list[i];
                        if (!widget.admin) {
                          return NoticeCard(
                            notice: n,
                            unread: !_read.contains('${n.id}'),
                            onTap: () => _open(n),
                          );
                        }
                        return Dismissible(
                          key: ValueKey('notice_${n.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            final repo = context.read<CampusRepository>();
                            final messenger = ScaffoldMessenger.of(context);
                            list.remove(n);
                            await repo.deleteNotice(n.id!);
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(
                                content: const Text('Notice deleted'),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    await repo.saveNotice(Notice(
                                        title: n.title,
                                        body: n.body,
                                        category: n.category,
                                        publishedOn: n.publishedOn,
                                        isPublished: n.isPublished));
                                    if (mounted) _reload();
                                  },
                                ),
                              ));
                          },
                          child: NoticeCard(
                            notice: n,
                            onTap: () => _open(n),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') _openForm(n);
                                if (v == 'toggle') _togglePublish(n);
                                if (v == 'delete') {
                                  final ok = await confirmDialog(context,
                                      title: 'Delete notice', message: 'Delete "${n.title}"?');
                                  if (ok && mounted) {
                                    await context.read<CampusRepository>().deleteNotice(n.id!);
                                    _reload();
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(n.isPublished ? 'Unpublish' : 'Publish')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
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

class NoticeFormScreen extends StatefulWidget {
  const NoticeFormScreen({super.key, this.notice});
  final Notice? notice;
  @override
  State<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends State<NoticeFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.notice?.title);
  late final _body = TextEditingController(text: widget.notice?.body);
  late String _category = widget.notice?.category ?? kNoticeCategories.first;
  late DateTime _date = widget.notice?.publishedOn ?? DateTime.now();
  late bool _publish = widget.notice?.isPublished ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<CampusRepository>().saveNotice(Notice(
            id: widget.notice?.id,
            title: _title.text.trim(),
            body: _body.text.trim(),
            category: _category,
            publishedOn: _date,
            isPublished: _publish,
          ));
      if (!mounted) return;
      showSnack(context, _publish ? 'Notice published' : 'Notice saved as draft');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.notice == null ? 'New notice' : 'Edit notice')),
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
                      controller: _title,
                      label: 'Title',
                      icon: Icons.title,
                      validator: (v) => Validators.required(v, 'Title')),
                  const SizedBox(height: 14),
                  AppTextField(
                      controller: _body,
                      label: 'Notice details',
                      icon: Icons.notes,
                      maxLines: 6,
                      validator: (v) => Validators.required(v, 'Details')),
                  const SizedBox(height: 14),
                  SelectField<String>(
                    label: 'Category',
                    icon: Icons.label_outline,
                    value: _category,
                    items: kNoticeCategories,
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await pickDate(context, _date,
                          first: DateTime(2020), last: DateTime(2100));
                      if (d != null) setState(() => _date = d);
                    },
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('Notice date: ${Fmt.date(_date)}'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish now'),
                    subtitle: const Text('Students are notified when a notice is published.'),
                    value: _publish,
                    onChanged: (v) => setState(() => _publish = v),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                      label: _publish ? 'Publish notice' : 'Save draft',
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

class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.notice});
  final Notice notice;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notice')),
      body: MaxWidth(
        width: 720,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                StatusChip(notice.category, categoryColor(notice.category)),
                if (!notice.isPublished) ...[
                  const SizedBox(width: 8),
                  const StatusChip('Draft', AppColors.amber),
                ],
                const Spacer(),
                Text(Fmt.weekdayDate(notice.publishedOn), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            Text(notice.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Text(notice.body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
