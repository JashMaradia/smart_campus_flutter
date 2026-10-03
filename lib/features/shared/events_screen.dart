import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';
import 'package:smart_campus/core/widgets/cards.dart';
import 'package:smart_campus/core/widgets/common.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

/// Campus events. Admins add, edit and delete; students browse upcoming/past.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.admin, this.embedded = false});
  final bool admin;
  final bool embedded;
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _version = 0;

  Future<void> _openForm([EventItem? e]) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => EventFormScreen(event: e)));
    if (saved == true && mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: PageScaffold(
          title: 'Events',
          embedded: widget.embedded,
          bottom: const TabBar(tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')]),
          fab: widget.admin
              ? FloatingActionButton.extended(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add event'),
                )
              : null,
          body: TabBarView(
            children: [
              _EventList(
                key: ValueKey('up$_version'),
                upcoming: true,
                admin: widget.admin,
                onEdit: _openForm,
                onChanged: () => setState(() => _version++),
              ),
              _EventList(
                key: ValueKey('past$_version'),
                upcoming: false,
                admin: widget.admin,
                onEdit: _openForm,
                onChanged: () => setState(() => _version++),
              ),
            ],
          ),
        ),
      );
}

class _EventList extends StatefulWidget {
  const _EventList({
    super.key,
    required this.upcoming,
    required this.admin,
    required this.onEdit,
    required this.onChanged,
  });
  final bool upcoming, admin;
  final void Function(EventItem) onEdit;
  final VoidCallback onChanged;
  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  late Future<List<EventItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<EventItem>> _load() =>
      context.read<CampusRepository>().events(upcoming: widget.upcoming);

  void _reload() => setState(() => _future = _load());

  Future<void> _delete(EventItem e) async {
    final ok = await confirmDialog(context,
        title: 'Delete event', message: 'Delete "${e.title}"?');
    if (!ok || !mounted) return;
    await context.read<CampusRepository>().deleteEvent(e.id!);
    if (!mounted) return;
    showSnack(context, 'Event deleted');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => MaxWidth(
        child: AsyncBody<List<EventItem>>(
          future: _future,
          onRetry: _reload,
          builder: (context, list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.event_busy_outlined,
                title: widget.upcoming ? 'No upcoming events' : 'No past events',
                message: widget.admin && widget.upcoming ? 'Tap "Add event" to create one.' : null,
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final e = list[i];
                  return EventCard(
                    event: e,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EventDetailScreen(event: e))),
                    trailing: widget.admin
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') widget.onEdit(e);
                              if (v == 'delete') _delete(e);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          )
                        : null,
                  );
                },
              ),
            );
          },
        ),
      );
}

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});
  final EventItem? event;
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _desc = TextEditingController(text: widget.event?.description);
  late final _location = TextEditingController(text: widget.event?.location);
  late DateTime _date = widget.event?.date ?? DateTime.now().add(const Duration(days: 7));
  late String _start = widget.event?.startTime ?? '10:00';
  late String _end = widget.event?.endTime ?? '12:00';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_end.compareTo(_start) <= 0) {
      setState(() => _error = 'End time must be after the start time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<CampusRepository>().saveEvent(EventItem(
            id: widget.event?.id,
            title: _title.text.trim(),
            description: _desc.text.trim(),
            date: DateTime(_date.year, _date.month, _date.day),
            startTime: _start,
            endTime: _end,
            location: _location.text.trim(),
          ));
      if (!mounted) return;
      showSnack(context, widget.event == null ? 'Event added' : 'Event updated');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _timeField(String label, String value, ValueChanged<String> onPicked) => InkWell(
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.event == null ? 'Add event' : 'Edit event')),
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
                    label: 'Event title',
                    icon: Icons.event_outlined,
                    validator: (v) => Validators.required(v, 'Title')),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await pickDate(context, _date,
                        first: DateTime(2020), last: DateTime(2100));
                    if (d != null) setState(() => _date = d);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('Date: ${Fmt.weekdayDate(_date)}'),
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
                    controller: _location,
                    label: 'Location',
                    icon: Icons.place_outlined,
                    validator: (v) => Validators.required(v, 'Location')),
                const SizedBox(height: 14),
                AppTextField(
                    controller: _desc,
                    label: 'Description',
                    icon: Icons.notes,
                    maxLines: 4,
                    validator: (v) => Validators.required(v, 'Description')),
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
                    label: widget.event == null ? 'Add event' : 'Save changes',
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

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event});
  final EventItem event;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: MaxWidth(
        width: 720,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(event.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  InfoRow('Date', Fmt.weekdayDate(event.date), icon: Icons.calendar_today_outlined),
                  InfoRow('Time', '${Fmt.time12(event.startTime)} - ${Fmt.time12(event.endTime)}',
                      icon: Icons.schedule),
                  InfoRow('Location', event.location, icon: Icons.place_outlined),
                ],
              ),
            ),
            const SectionHeader('About this event'),
            Text(event.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
