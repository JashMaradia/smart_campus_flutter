import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Salted SHA-256 password hashing (plain text is never stored).
class PasswordHasher {
  static String newSalt() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}

class Fmt {
  static final DateFormat _dbFmt = DateFormat('yyyy-MM-dd');

  static String dbDate(DateTime d) => _dbFmt.format(d);
  static DateTime parseDb(String s) => DateTime.parse(s);
  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dayMonth(DateTime d) => DateFormat('d MMM').format(d);
  static String weekdayDate(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);
  static String money(int v) => NumberFormat.decimalPattern('en_IN').format(v);
  static String rupees(int v) => '\u20B9${money(v)}';

  /// Plain ASCII currency (PDF default fonts have no rupee glyph).
  static String rs(int v) => 'Rs ${money(v)}';

  /// '13:05' -> '1:05 PM'
  static String time12(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $suffix';
  }

  static String timeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String nowHHmm() => timeOfDay(TimeOfDay.now());

  static String ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return date(t);
  }
}

/// True when [s1,e1) overlaps [s2,e2). Times are zero padded 24h 'HH:mm'.
bool timesOverlap(String s1, String e1, String s2, String e2) =>
    s1.compareTo(e2) < 0 && e1.compareTo(s2) > 0;

/// Attendance percentage; late counts as attended.
double attendancePercent(int attended, int total) =>
    total == 0 ? 0 : attended * 100 / total;

String initials(String name) {
  final list =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (list.isEmpty) return '?';
  final first = list.first[0];
  final last = list.length > 1 ? list.last[0] : '';
  return (first + last).toUpperCase();
}

Color attendanceColor(double pct) {
  if (pct >= 85) return const Color(0xFF15803D);
  if (pct >= 75) return const Color(0xFF1E40AF);
  return const Color(0xFFB91C1C);
}

/// Copies a picked file into the app's documents folder so it survives cache clears.
Future<String> persistFile(String sourcePath, String folder) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, folder));
  if (!await dir.exists()) await dir.create(recursive: true);
  final name = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
  final dest = p.join(dir.path, name);
  await File(sourcePath).copy(dest);
  return dest;
}
