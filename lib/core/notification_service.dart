import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules device (system tray) reminders for fee due dates and events.
///
/// Reminders are rebuilt from the database each time a student opens the app,
/// so edits made by the admin are picked up on the next launch.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'campus_reminders';
  static const _channelName = 'Campus reminders';
  static const _feeBaseId = 1000; // 1000..1009
  static const _eventBaseId = 100000; // + eventId * 2 (+1 for the day-before one)

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_ready || !_supported) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      debugPrint('NotificationService timezone setup failed: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for the notification permission (Android 13+ and iOS).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Replaces all scheduled reminders with ones for the given fee and events.
  Future<void> sync({required FeeSummary fee, required List<EventItem> events}) async {
    if (!_ready) return;
    try {
      if (!await requestPermission()) return;
      await _plugin.cancelAll();
      await _scheduleFees(fee);
      for (final e in events) {
        await _scheduleEvent(e);
      }
    } catch (e, st) {
      debugPrint('NotificationService sync failed: $e\n$st');
    }
  }

  Future<void> _scheduleFees(FeeSummary fee) async {
    final due = fee.dueDate;
    if (due == null || fee.pending <= 0) return;
    final amount = Fmt.rupees(fee.pending);
    final dueText = Fmt.date(due);
    var id = _feeBaseId;
    // 3 days before, 1 day before and on the due date, all at 9:00 AM.
    for (final daysBefore in const [3, 1, 0]) {
      final when = DateTime(due.year, due.month, due.day, 9)
          .subtract(Duration(days: daysBefore));
      final body = daysBefore == 0
          ? '$amount is due today ($dueText).'
          : '$amount is due in $daysBefore day${daysBefore == 1 ? '' : 's'} ($dueText).';
      await _schedule(id++, when, 'Fee payment reminder', body);
    }
    // If already overdue, nudge once tomorrow morning.
    if (due.isBefore(DateTime.now())) {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day, 9).add(const Duration(days: 1));
      await _schedule(id, tomorrow, 'Fee payment overdue',
          '$amount was due on $dueText. Please pay at the accounts office.');
    }
  }

  Future<void> _scheduleEvent(EventItem e) async {
    if (e.id == null) return;
    final parts = e.startTime.split(':');
    final h = int.tryParse(parts.first) ?? 9;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final start = DateTime(e.date.year, e.date.month, e.date.day, h, m);
    final base = _eventBaseId + e.id! * 2;
    await _schedule(base, start.subtract(const Duration(hours: 1)),
        'Event starts in 1 hour', '${e.title} at ${e.location}.');
    await _schedule(
        base + 1,
        DateTime(start.year, start.month, start.day, 18).subtract(const Duration(days: 1)),
        'Event tomorrow: ${e.title}',
        '${Fmt.time12(e.startTime)} at ${e.location}.');
  }

  /// Schedules one reminder; silently skips times that are already in the past.
  Future<void> _schedule(int id, DateTime when, String title, String body) async {
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Fee due dates and upcoming events',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact: no special "exact alarm" permission needed (may fire a few minutes late).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
