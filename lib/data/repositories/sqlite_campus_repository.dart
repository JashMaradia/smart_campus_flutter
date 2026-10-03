import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/data/local/app_database.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:sqflite/sqflite.dart';

int _n(Object? v) => (v as num?)?.toInt() ?? 0;

/// SQLite implementation of [CampusRepository].
class SqliteCampusRepository implements CampusRepository {
  Future<Database> get _d => AppDatabase.instance.database;
  String _now() => DateTime.now().toIso8601String();

  // ------------------------------------------------------------------ helpers
  Future<void> _log(DatabaseExecutor ex, String message) async {
    await ex.insert('activity_log', {'message': message, 'created_at': _now()});
  }

  /// Creates an in-app notification. With [dedupe] the same title is not
  /// created again for the same user within 24 hours.
  Future<void> _notify(DatabaseExecutor ex, int userId, String type,
      String title, String message,
      {bool dedupe = false}) async {
    if (dedupe) {
      final since =
          DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      final existing = await ex.query('notifications',
          where: 'user_id = ? AND title = ? AND created_at >= ?',
          whereArgs: [userId, title, since],
          limit: 1);
      if (existing.isNotEmpty) return;
    }
    await ex.insert('notifications', {
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'created_at': _now(),
      'is_read': 0,
    });
  }

  Future<void> _notifyStudents(DatabaseExecutor ex,
      {String? program,
      int? semester,
      required String type,
      required String title,
      required String message}) async {
    final where = <String>['user_id IS NOT NULL'];
    final args = <Object?>[];
    if (program != null) {
      where.add('program = ?');
      args.add(program);
    }
    if (semester != null) {
      where.add('semester = ?');
      args.add(semester);
    }
    final rows = await ex.query('students',
        columns: ['user_id'], where: where.join(' AND '), whereArgs: args);
    for (final r in rows) {
      await _notify(ex, r['user_id'] as int, type, title, message);
    }
  }

  // ----------------------------------------------------------------- settings
  @override
  Future<String?> getSetting(String name) async {
    final db = await _d;
    final r = await db.query('app_settings',
        where: 'name = ?', whereArgs: [name], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String name, String value) async {
    final db = await _d;
    await db.insert('app_settings', {'name': name, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --------------------------------------------------------------------- auth
  @override
  Future<AppUser?> findUser(String loginId) async {
    final db = await _d;
    final rows = await db.query('users',
        where: 'login_id = ? COLLATE NOCASE OR email = ? COLLATE NOCASE',
        whereArgs: [loginId, loginId],
        limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  @override
  Future<AppUser?> getUser(int id) async {
    final db = await _d;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  @override
  Future<bool> verifyPassword(AppUser user, String password) async =>
      PasswordHasher.hash(password, user.salt) == user.passwordHash;

  @override
  Future<void> changePassword(int userId, String newPassword) async {
    final db = await _d;
    final salt = PasswordHasher.newSalt();
    await db.update(
        'users',
        {
          'salt': salt,
          'password_hash': PasswordHasher.hash(newPassword, salt),
        },
        where: 'id = ?',
        whereArgs: [userId]);
  }

  @override
  Future<String?> activateStudentAccount({
    required String studentId,
    required String email,
    required String password,
  }) async {
    final db = await _d;
    final rows = await db.query('students',
        where: 'student_id = ? COLLATE NOCASE AND email = ? COLLATE NOCASE',
        whereArgs: [studentId.trim(), email.trim()],
        limit: 1);
    if (rows.isEmpty) {
      return 'No student record matches this Student ID and email. Please contact the admin.';
    }
    final s = Student.fromMap(rows.first);
    if (s.userId != null) {
      return 'An account already exists for this student. Please log in.';
    }
    await db.transaction((txn) async {
      final salt = PasswordHasher.newSalt();
      final uid = await txn.insert('users', {
        'login_id': s.studentId,
        'email': s.email,
        'name': s.name,
        'phone': s.phone,
        'role': 'student',
        'password_hash': PasswordHasher.hash(password, salt),
        'salt': salt,
        'dob': s.dob,
        'created_at': _now(),
      });
      await txn.update('students', {'user_id': uid},
          where: 'id = ?', whereArgs: [s.id]);
    });
    return null;
  }

  @override
  Future<AppUser?> verifyRecovery({
    required String loginId,
    required String email,
    required DateTime dob,
  }) async {
    final user = await findUser(loginId.trim());
    if (user == null) return null;
    if (user.email.toLowerCase() != email.trim().toLowerCase()) return null;
    final dobStr = Fmt.dbDate(dob);
    if (user.role == 'admin') return user.dob == dobStr ? user : null;
    final s = await studentByUserId(user.id);
    return (s != null && s.dob == dobStr) ? user : null;
  }

  @override
  Future<void> updateUserProfile(int userId,
      {required String name, required String phone}) async {
    final db = await _d;
    await db.update('users', {'name': name, 'phone': phone},
        where: 'id = ?', whereArgs: [userId]);
  }

  // ----------------------------------------------------------------- students
  @override
  Future<List<Student>> students(
      {String query = '', String? program, int? semester}) async {
    final db = await _d;
    final where = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      where.add('(name LIKE ? OR student_id LIKE ? OR email LIKE ?)');
      args.addAll([q, q, q]);
    }
    if (program != null) {
      where.add('program = ?');
      args.add(program);
    }
    if (semester != null) {
      where.add('semester = ?');
      args.add(semester);
    }
    final rows = await db.query('students',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'name COLLATE NOCASE');
    return rows.map(Student.fromMap).toList();
  }

  @override
  Future<Student?> studentById(int id) async {
    final db = await _d;
    final rows = await db.query('students', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  @override
  Future<Student?> studentByUserId(int userId) async {
    final db = await _d;
    final rows = await db.query('students',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  @override
  Future<String?> saveStudent(Student s, {bool createAccount = false}) async {
    final db = await _d;
    try {
      final dup = await db.query('students',
          where: 'student_id = ? COLLATE NOCASE AND id != ?',
          whereArgs: [s.studentId, s.id ?? -1],
          limit: 1);
      if (dup.isNotEmpty) return 'Student ID ${s.studentId} already exists.';
      if (s.id == null) {
        if (createAccount) {
          final clash = await db.query('users',
              where: 'login_id = ? COLLATE NOCASE',
              whereArgs: [s.studentId],
              limit: 1);
          if (clash.isNotEmpty) return 'A login with this ID already exists.';
        }
        await db.transaction((txn) async {
          int? uid;
          if (createAccount) {
            final salt = PasswordHasher.newSalt();
            uid = await txn.insert('users', {
              'login_id': s.studentId,
              'email': s.email,
              'name': s.name,
              'phone': s.phone,
              'role': 'student',
              'password_hash':
                  PasswordHasher.hash(AppStrings.defaultStudentPassword, salt),
              'salt': salt,
              'dob': s.dob,
              'created_at': _now(),
            });
          }
          await txn.insert('students', {...s.toMap(), 'user_id': uid});
          await _log(txn, 'New student added: ${s.name}');
        });
      } else {
        await db.transaction((txn) async {
          await txn.update('students', s.toMap(),
              where: 'id = ?', whereArgs: [s.id]);
          if (s.userId != null) {
            await txn.update(
                'users',
                {
                  'login_id': s.studentId,
                  'email': s.email,
                  'name': s.name,
                  'phone': s.phone,
                  'dob': s.dob,
                },
                where: 'id = ?',
                whereArgs: [s.userId]);
          }
          await _log(txn, 'Student updated: ${s.name}');
        });
      }
      return null;
    } on DatabaseException catch (e) {
      return 'Could not save the student: $e';
    }
  }

  @override
  Future<void> deleteStudent(int id) async {
    final db = await _d;
    final s = await studentById(id);
    if (s == null) return;
    await db.transaction((txn) async {
      await txn.delete('students', where: 'id = ?', whereArgs: [id]);
      if (s.userId != null) {
        await txn.delete('users', where: 'id = ?', whereArgs: [s.userId]);
      }
      await _log(txn, 'Student removed: ${s.name}');
    });
  }

  @override
  Future<void> updateStudentSelf(int id,
      {required String phone, required String address, String? photoPath}) async {
    final db = await _d;
    final s = await studentById(id);
    if (s == null) return;
    final values = <String, Object?>{'phone': phone, 'address': address};
    if (photoPath != null) values['photo_path'] = photoPath;
    await db.transaction((txn) async {
      await txn.update('students', values, where: 'id = ?', whereArgs: [id]);
      if (s.userId != null) {
        await txn.update('users', {'phone': phone},
            where: 'id = ?', whereArgs: [s.userId]);
      }
    });
  }

  // ------------------------------------------------------------------ faculty
  @override
  Future<List<Faculty>> faculty() async {
    final db = await _d;
    final rows = await db.query('faculty', orderBy: 'name COLLATE NOCASE');
    return rows.map(Faculty.fromMap).toList();
  }

  @override
  Future<void> saveFaculty(Faculty f) async {
    final db = await _d;
    await db.transaction((txn) async {
      if (f.id == null) {
        await txn.insert('faculty', f.toMap());
        await _log(txn, 'New faculty added: ${f.name}');
      } else {
        await txn.update('faculty', f.toMap(), where: 'id = ?', whereArgs: [f.id]);
        await _log(txn, 'Faculty updated: ${f.name}');
      }
    });
  }

  @override
  Future<void> deleteFaculty(int id) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.delete('faculty', where: 'id = ?', whereArgs: [id]);
      await _log(txn, 'Faculty member removed');
    });
  }

  @override
  Future<void> assignCourses(int facultyId, Set<int> courseIds) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.update('courses', {'faculty_id': null},
          where: 'faculty_id = ?', whereArgs: [facultyId]);
      for (final cid in courseIds) {
        await txn.update('courses', {'faculty_id': facultyId},
            where: 'id = ?', whereArgs: [cid]);
        await txn.update('timetable', {'faculty_id': facultyId},
            where: 'course_id = ?', whereArgs: [cid]);
      }
      await _log(txn, 'Course assignments updated for a faculty member');
    });
  }

  // ------------------------------------------------------------------ courses
  @override
  Future<List<Course>> courses({String? program, int? semester}) async {
    final db = await _d;
    final where = <String>[];
    final args = <Object?>[];
    if (program != null) {
      where.add('c.program = ?');
      args.add(program);
    }
    if (semester != null) {
      where.add('c.semester = ?');
      args.add(semester);
    }
    final rows = await db.rawQuery(
        'SELECT c.*, f.name AS faculty_name FROM courses c '
        'LEFT JOIN faculty f ON f.id = c.faculty_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY c.program, c.semester, c.code',
        args);
    return rows.map(Course.fromMap).toList();
  }

  @override
  Future<List<Course>> coursesForStudent(Student s) =>
      courses(program: s.program, semester: s.semester);

  @override
  Future<String?> saveCourse(Course c) async {
    final db = await _d;
    final dup = await db.query('courses',
        where: 'code = ? COLLATE NOCASE AND id != ?',
        whereArgs: [c.code, c.id ?? -1],
        limit: 1);
    if (dup.isNotEmpty) return 'Course code ${c.code} already exists.';
    await db.transaction((txn) async {
      if (c.id == null) {
        await txn.insert('courses', c.toMap());
        await _log(txn, 'New course added: ${c.code} ${c.name}');
      } else {
        await txn.update('courses', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
        await _log(txn, 'Course updated: ${c.code} ${c.name}');
      }
    });
    return null;
  }

  @override
  Future<void> deleteCourse(int id) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.delete('courses', where: 'id = ?', whereArgs: [id]);
      await _log(txn, 'Course removed');
    });
  }

  @override
  Future<List<CourseMaterial>> materials(int courseId) async {
    final db = await _d;
    final rows = await db.query('course_materials',
        where: 'course_id = ?', whereArgs: [courseId], orderBy: 'id DESC');
    return rows.map(CourseMaterial.fromMap).toList();
  }

  @override
  Future<void> addMaterial(int courseId, String title, String path) async {
    final db = await _d;
    await db.insert('course_materials', {
      'course_id': courseId,
      'title': title,
      'file_path': path,
      'added_on': _now(),
    });
  }

  @override
  Future<void> deleteMaterial(int id) async {
    final db = await _d;
    await db.delete('course_materials', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- timetable
  static const String _ttSelect =
      'SELECT t.*, c.code AS course_code, c.name AS course_name, '
      'c.program AS program, c.semester AS semester, f.name AS faculty_name '
      'FROM timetable t JOIN courses c ON c.id = t.course_id '
      'LEFT JOIN faculty f ON f.id = t.faculty_id';

  @override
  Future<List<TimetableEntry>> timetable(
      {String? program, int? semester, int? day}) async {
    final db = await _d;
    final where = <String>[];
    final args = <Object?>[];
    if (program != null && program.trim().isNotEmpty) {
      where.add('c.program = ? COLLATE NOCASE');
      args.add(program.trim());
    }
    if (semester != null) {
      where.add('c.semester = ?');
      args.add(semester);
    }
    if (day != null) {
      where.add('t.day_of_week = ?');
      args.add(day);
    }
    final rows = await db.rawQuery(
        '$_ttSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY t.day_of_week, t.start_time',
        args);
    return rows.map(TimetableEntry.fromMap).toList();
  }

  @override
  Future<List<TimetableEntry>> timetableForStudent(Student s) =>
      timetable(program: s.program, semester: s.semester);

  @override
  Future<String?> saveTimetable(TimetableEntry e) async {
    if (e.end.compareTo(e.start) <= 0) {
      return 'End time must be after the start time.';
    }
    if (e.room.trim().isEmpty) return 'Room is required.';
    final db = await _d;
    final cRows = await db.query('courses',
        where: 'id = ?', whereArgs: [e.courseId], limit: 1);
    if (cRows.isEmpty) return 'Please select a course.';
    final course = Course.fromMap(cRows.first);
    final sameDay =
        await db.rawQuery('$_ttSelect WHERE t.day_of_week = ?', [e.day]);
    for (final r in sameDay.map(TimetableEntry.fromMap)) {
      if (r.id == e.id) continue;
      if (!timesOverlap(r.start, r.end, e.start, e.end)) continue;
      final when = '${Fmt.time12(r.start)} - ${Fmt.time12(r.end)}';
      if (r.room.toLowerCase() == e.room.trim().toLowerCase()) {
        return 'Room clash: ${r.room} is already used by ${r.courseName} ($when).';
      }
      if (e.facultyId != null && r.facultyId == e.facultyId) {
        return 'Faculty clash: ${r.facultyName} already teaches ${r.courseName} ($when).';
      }
      if (r.program == course.program && r.semester == course.semester) {
        return 'Class clash: ${course.program} Sem ${course.semester} already has ${r.courseName} ($when).';
      }
    }
    final values = <String, Object?>{...e.toMap(), 'room': e.room.trim()};
    await db.transaction((txn) async {
      if (e.id == null) {
        await txn.insert('timetable', values);
      } else {
        await txn.update('timetable', values, where: 'id = ?', whereArgs: [e.id]);
      }
      await _notifyStudents(txn,
          program: course.program,
          semester: course.semester,
          type: 'timetable',
          title: 'Timetable updated',
          message:
              '${course.name} is on ${dayName(e.day)} at ${Fmt.time12(e.start)} in ${e.room.trim()}.');
      await _log(txn,
          'Timetable updated for ${course.code}, ${course.program} Sem ${course.semester}');
    });
    return null;
  }

  @override
  Future<void> deleteTimetable(int id) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.delete('timetable', where: 'id = ?', whereArgs: [id]);
      await _log(txn, 'Timetable entry removed');
    });
  }

  // --------------------------------------------------------------- attendance
  @override
  Future<List<AttendanceMark>> attendanceSheet(int courseId, DateTime date) async {
    final db = await _d;
    final rows = await db.rawQuery(
        'SELECT s.id AS pk, s.student_id AS code, s.name AS name, a.status AS status '
        'FROM courses c JOIN students s ON s.program = c.program AND s.semester = c.semester '
        'LEFT JOIN attendance a ON a.student_id = s.id AND a.course_id = c.id AND a.date = ? '
        'WHERE c.id = ? ORDER BY s.name COLLATE NOCASE',
        [Fmt.dbDate(date), courseId]);
    return rows
        .map((m) => AttendanceMark(
              studentPk: _n(m['pk']),
              code: m['code'] as String,
              name: m['name'] as String,
              status: m['status'] as String?,
            ))
        .toList();
  }

  @override
  Future<void> saveAttendance(
      int courseId, DateTime date, Map<int, String> statuses) async {
    final db = await _d;
    final dateStr = Fmt.dbDate(date);
    final cRows = await db.query('courses',
        where: 'id = ?', whereArgs: [courseId], limit: 1);
    if (cRows.isEmpty) return;
    final course = Course.fromMap(cRows.first);
    await db.transaction((txn) async {
      final batch = txn.batch();
      statuses.forEach((studentPk, status) {
        batch.insert(
            'attendance',
            {
              'student_id': studentPk,
              'course_id': courseId,
              'date': dateStr,
              'status': status,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      });
      await batch.commit(noResult: true);
      for (final entry in statuses.entries) {
        if (entry.value != 'absent') continue;
        final rows = await txn.rawQuery(
            "SELECT SUM(CASE WHEN status IN ('present','late') THEN 1 ELSE 0 END) AS attended, "
            'COUNT(*) AS total, (SELECT user_id FROM students WHERE id = ?) AS uid '
            'FROM attendance WHERE student_id = ? AND course_id = ?',
            [entry.key, entry.key, courseId]);
        final r = rows.first;
        final uid = r['uid'] as int?;
        final total = _n(r['total']);
        final pct = attendancePercent(_n(r['attended']), total);
        if (uid != null && total > 0 && pct < AppStrings.minAttendance) {
          await _notify(
              txn,
              uid,
              'attendance',
              'Low attendance in ${course.name}',
              'Your attendance is ${pct.toStringAsFixed(0)}%. The minimum required is ${AppStrings.minAttendance}%.',
              dedupe: true);
        }
      }
      await _log(txn,
          'Attendance updated for ${course.code}, ${course.program} Sem ${course.semester}');
    });
  }

  @override
  Future<List<SubjectAttendance>> subjectAttendance(int studentId) async {
    final db = await _d;
    final rows = await db.rawQuery(
        'SELECT c.id AS course_id, c.code AS code, c.name AS name, '
        "SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) AS present, "
        "SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) AS late, "
        "SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) AS absent, "
        'COUNT(a.id) AS total '
        'FROM attendance a JOIN courses c ON c.id = a.course_id '
        'WHERE a.student_id = ? GROUP BY c.id ORDER BY c.name',
        [studentId]);
    return rows
        .map((m) => SubjectAttendance(
              courseId: _n(m['course_id']),
              code: m['code'] as String,
              name: m['name'] as String,
              present: _n(m['present']),
              late: _n(m['late']),
              absent: _n(m['absent']),
              total: _n(m['total']),
            ))
        .toList();
  }

  @override
  Future<List<AttendanceEntry>> attendanceHistory(int studentId,
      {int? courseId}) async {
    final db = await _d;
    final rows = await db.rawQuery(
        'SELECT a.date AS date, a.status AS status, c.name AS course_name '
        'FROM attendance a JOIN courses c ON c.id = a.course_id '
        'WHERE a.student_id = ? ${courseId == null ? '' : 'AND a.course_id = ?'} '
        'ORDER BY a.date DESC, c.name LIMIT 300',
        [studentId, if (courseId != null) courseId]);
    return rows
        .map((m) => AttendanceEntry(
              date: DateTime.parse(m['date'] as String),
              courseName: m['course_name'] as String,
              status: m['status'] as String,
            ))
        .toList();
  }

  @override
  Future<List<StudentAttendanceSummary>> attendanceOverview({
    String? program,
    int? semester,
    int? courseId,
    String query = '',
  }) async {
    final db = await _d;
    final onArgs = <Object?>[];
    final where = <String>[];
    final whereArgs = <Object?>[];
    var on = 'a.student_id = s.id';
    if (courseId != null) {
      on += ' AND a.course_id = ?';
      onArgs.add(courseId);
      where.add('EXISTS (SELECT 1 FROM courses c WHERE c.id = ? '
          'AND c.program = s.program AND c.semester = s.semester)');
      whereArgs.add(courseId);
    }
    if (program != null) {
      where.add('s.program = ?');
      whereArgs.add(program);
    }
    if (semester != null) {
      where.add('s.semester = ?');
      whereArgs.add(semester);
    }
    if (query.trim().isNotEmpty) {
      where.add('(s.name LIKE ? OR s.student_id LIKE ?)');
      whereArgs.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    final rows = await db.rawQuery(
        'SELECT s.id AS pk, s.student_id AS code, s.name AS name, '
        's.program AS program, s.semester AS semester, '
        "SUM(CASE WHEN a.status IN ('present','late') THEN 1 ELSE 0 END) AS attended, "
        'COUNT(a.id) AS total '
        'FROM students s LEFT JOIN attendance a ON $on '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'GROUP BY s.id ORDER BY s.name COLLATE NOCASE',
        [...onArgs, ...whereArgs]);
    return rows
        .map((m) => StudentAttendanceSummary(
              studentPk: _n(m['pk']),
              code: m['code'] as String,
              name: m['name'] as String,
              program: m['program'] as String,
              semester: _n(m['semester']),
              attended: _n(m['attended']),
              total: _n(m['total']),
            ))
        .toList();
  }

  // ----------------------------------------------------------- notices/events
  @override
  Future<List<Notice>> notices(
      {bool publishedOnly = false, String? category, String query = ''}) async {
    final db = await _d;
    final where = <String>[];
    final args = <Object?>[];
    if (publishedOnly) where.add('is_published = 1');
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    if (query.trim().isNotEmpty) {
      where.add('(title LIKE ? OR body LIKE ?)');
      args.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    final rows = await db.query('notices',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'published_on DESC, id DESC');
    return rows.map(Notice.fromMap).toList();
  }

  @override
  Future<void> saveNotice(Notice n) async {
    final db = await _d;
    var wasPublished = false;
    if (n.id != null) {
      final old = await db.query('notices',
          where: 'id = ?', whereArgs: [n.id], limit: 1);
      if (old.isNotEmpty) wasPublished = Notice.fromMap(old.first).isPublished;
    }
    await db.transaction((txn) async {
      if (n.id == null) {
        await txn.insert('notices', n.toMap());
      } else {
        await txn.update('notices', n.toMap(), where: 'id = ?', whereArgs: [n.id]);
      }
      if (n.isPublished && !wasPublished) {
        await _notifyStudents(txn,
            type: 'notice',
            title: 'New notice: ${n.title}',
            message: n.body.length > 90 ? '${n.body.substring(0, 90)}...' : n.body);
        await _log(txn, 'Notice published: ${n.title}');
      } else {
        await _log(txn, 'Notice saved: ${n.title}');
      }
    });
  }

  @override
  Future<void> deleteNotice(int id) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.delete('notices', where: 'id = ?', whereArgs: [id]);
      await _log(txn, 'Notice deleted');
    });
  }

  @override
  Future<List<EventItem>> events({bool? upcoming}) async {
    final db = await _d;
    final today = Fmt.dbDate(DateTime.now());
    final rows = await db.query('events',
        where: upcoming == null ? null : (upcoming ? 'date >= ?' : 'date < ?'),
        whereArgs: upcoming == null ? null : [today],
        orderBy: upcoming == true ? 'date ASC, start_time ASC' : 'date DESC');
    return rows.map(EventItem.fromMap).toList();
  }

  @override
  Future<void> saveEvent(EventItem e) async {
    final db = await _d;
    await db.transaction((txn) async {
      if (e.id == null) {
        await txn.insert('events', e.toMap());
        await _notifyStudents(txn,
            type: 'event',
            title: 'New event: ${e.title}',
            message: '${Fmt.date(e.date)}, ${Fmt.time12(e.startTime)} at ${e.location}.');
        await _log(txn, 'Event created: ${e.title}');
      } else {
        await txn.update('events', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
        await _log(txn, 'Event updated: ${e.title}');
      }
    });
  }

  @override
  Future<void> deleteEvent(int id) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.delete('events', where: 'id = ?', whereArgs: [id]);
      await _log(txn, 'Event deleted');
    });
  }

  // --------------------------------------------------------------------- fees
  @override
  Future<List<FeeStructure>> feeStructures() async {
    final db = await _d;
    final rows = await db.query('fee_structures', orderBy: 'program, semester');
    return rows.map(FeeStructure.fromMap).toList();
  }

  @override
  Future<void> saveFeeStructure(FeeStructure f) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.insert(
          'fee_structures',
          {
            'program': f.program,
            'semester': f.semester,
            'total_amount': f.totalAmount,
            'due_date': Fmt.dbDate(f.dueDate),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _log(txn, 'Fee structure saved for ${f.program} Sem ${f.semester}');
    });
  }

  Future<List<FeeSummary>> _feeRows(String? where, List<Object?> args) async {
    final db = await _d;
    final rows = await db.rawQuery(
        'SELECT s.*, COALESCE(fs.total_amount, 0) AS total, fs.due_date AS due_date, '
        'COALESCE((SELECT SUM(p.amount) FROM fee_payments p WHERE p.student_id = s.id), 0) AS paid '
        'FROM students s LEFT JOIN fee_structures fs '
        'ON fs.program = s.program AND fs.semester = s.semester '
        '${where == null ? '' : 'WHERE $where'} ORDER BY s.name COLLATE NOCASE',
        args);
    return rows
        .map((m) => FeeSummary(
              student: Student.fromMap(m),
              total: _n(m['total']),
              paid: _n(m['paid']),
              dueDate: m['due_date'] == null
                  ? null
                  : DateTime.tryParse(m['due_date'] as String),
            ))
        .toList();
  }

  @override
  Future<FeeSummary> feeSummary(Student s) async {
    if (s.id == null) return FeeSummary(student: s, total: 0, paid: 0);
    final list = await _feeRows('s.id = ?', [s.id]);
    if (list.isEmpty) return FeeSummary(student: s, total: 0, paid: 0);
    return list.first;
  }

  @override
  Future<List<FeeSummary>> allFeeSummaries(
      {String query = '', String? status}) async {
    final q = query.trim();
    final list = await _feeRows(
        q.isEmpty ? null : '(s.name LIKE ? OR s.student_id LIKE ?)',
        q.isEmpty ? [] : ['%$q%', '%$q%']);
    return status == null ? list : list.where((f) => f.status == status).toList();
  }

  @override
  Future<List<Payment>> payments(int studentId) async {
    final db = await _d;
    final rows = await db.query('fee_payments',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'paid_on DESC, id DESC');
    return rows.map(Payment.fromMap).toList();
  }

  @override
  Future<Payment> recordPayment(int studentId, int amount, String method) async {
    final db = await _d;
    late Payment payment;
    await db.transaction((txn) async {
      final count = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM fee_payments')) ??
          0;
      final receipt = 'R-${1001 + count}';
      final now = DateTime.now();
      final id = await txn.insert('fee_payments', {
        'student_id': studentId,
        'amount': amount,
        'paid_on': Fmt.dbDate(now),
        'method': method,
        'receipt_no': receipt,
      });
      final sRows = await txn.query('students',
          where: 'id = ?', whereArgs: [studentId], limit: 1);
      final s = Student.fromMap(sRows.first);
      if (s.userId != null) {
        await _notify(txn, s.userId!, 'fee', 'Payment received',
            '${Fmt.rs(amount)} received via $method. Receipt $receipt.');
      }
      await _log(txn, 'Fee payment recorded, receipt $receipt');
      payment = Payment(
          id: id,
          studentId: studentId,
          amount: amount,
          paidOn: now,
          method: method,
          receiptNo: receipt);
    });
    return payment;
  }

  // ----------------------------------------------------------- notifications
  @override
  Future<List<AppNotification>> notifications(int userId) async {
    final db = await _d;
    final rows = await db.query('notifications',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC, id DESC');
    return rows.map(AppNotification.fromMap).toList();
  }

  @override
  Future<int> unreadCount(int userId) async {
    final db = await _d;
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0',
            [userId])) ??
        0;
  }

  @override
  Future<void> markRead(int id) async {
    final db = await _d;
    await db.update('notifications', {'is_read': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> markAllRead(int userId) async {
    final db = await _d;
    await db.update('notifications', {'is_read': 1},
        where: 'user_id = ?', whereArgs: [userId]);
  }

  @override
  Future<void> refreshStudentAlerts(Student s) async {
    final uid = s.userId;
    if (uid == null || s.id == null) return;
    final db = await _d;
    final fee = await feeSummary(s);
    if (fee.pending > 0 && fee.dueDate != null) {
      final days = fee.dueDate!.difference(DateTime.now()).inDays;
      if (days <= 14) {
        await _notify(
            db,
            uid,
            'fee',
            days < 0 ? 'Fee payment overdue' : 'Fee payment due soon',
            '${Fmt.rupees(fee.pending)} is pending. Due date: ${Fmt.date(fee.dueDate!)}.',
            dedupe: true);
      }
    }
    for (final sub in await subjectAttendance(s.id!)) {
      if (sub.total > 0 && sub.pct < AppStrings.minAttendance) {
        await _notify(
            db,
            uid,
            'attendance',
            'Low attendance in ${sub.name}',
            'Your attendance is ${sub.pct.toStringAsFixed(0)}%. The minimum required is ${AppStrings.minAttendance}%.',
            dedupe: true);
      }
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final e in await events(upcoming: true)) {
      if (e.date.difference(today).inDays <= 3) {
        await _notify(db, uid, 'event', 'Upcoming event: ${e.title}',
            '${Fmt.date(e.date)}, ${Fmt.time12(e.startTime)} at ${e.location}.',
            dedupe: true);
      }
    }
  }

  // ----------------------------------------------------------------- requests
  @override
  Future<List<CampusRequest>> requests({int? studentId, String? status}) async {
    final db = await _d;
    final where = <String>[];
    final args = <Object?>[];
    if (studentId != null) {
      where.add('r.student_id = ?');
      args.add(studentId);
    }
    if (status != null) {
      where.add('r.status = ?');
      args.add(status);
    }
    final rows = await db.rawQuery(
        'SELECT r.*, s.name AS student_name, s.student_id AS student_code '
        'FROM requests r JOIN students s ON s.id = r.student_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY r.id DESC',
        args);
    return rows.map(CampusRequest.fromMap).toList();
  }

  @override
  Future<void> createRequest(int studentId, String type, String details) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.insert('requests', {
        'student_id': studentId,
        'type': type,
        'details': details,
        'status': 'Pending',
        'created_at': _now(),
      });
      await _log(txn, 'New request submitted: $type');
    });
  }

  @override
  Future<void> setRequestStatus(int id, String status) async {
    final db = await _d;
    final rows = await db.rawQuery(
        'SELECT r.type AS type, s.user_id AS uid FROM requests r '
        'JOIN students s ON s.id = r.student_id WHERE r.id = ?',
        [id]);
    await db.transaction((txn) async {
      await txn.update('requests', {'status': status},
          where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty && rows.first['uid'] != null) {
        await _notify(txn, rows.first['uid'] as int, 'request',
            'Request ${status.toLowerCase()}',
            'Your request for ${rows.first['type']} was ${status.toLowerCase()}.');
      }
      await _log(txn, 'Request ${status.toLowerCase()}');
    });
  }

  // ------------------------------------------------------- dashboard/reports
  @override
  Future<AdminStats> adminStats() async {
    final db = await _d;
    Future<int> count(String sql, [List<Object?>? args]) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;

    final today = Fmt.dbDate(DateTime.now());
    final overall = await db.rawQuery(
        "SELECT SUM(CASE WHEN status IN ('present','late') THEN 1 ELSE 0 END) AS a, "
        'COUNT(*) AS t FROM attendance');
    final attendancePct =
        attendancePercent(_n(overall.first['a']), _n(overall.first['t']));

    final trend = <double>[];
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    for (var w = 5; w >= 0; w--) {
      final end = base.subtract(Duration(days: 7 * w));
      final start = end.subtract(const Duration(days: 7));
      final r = await db.rawQuery(
          "SELECT SUM(CASE WHEN status IN ('present','late') THEN 1 ELSE 0 END) AS a, "
          'COUNT(*) AS t FROM attendance WHERE date >= ? AND date < ?',
          [Fmt.dbDate(start), Fmt.dbDate(end)]);
      if (_n(r.first['t']) > 0) {
        trend.add(attendancePercent(_n(r.first['a']), _n(r.first['t'])));
      }
    }

    final perProgram = <String, int>{};
    final pRows = await db.rawQuery(
        'SELECT program, COUNT(*) AS n FROM students GROUP BY program ORDER BY program');
    for (final r in pRows) {
      perProgram[r['program'] as String] = _n(r['n']);
    }

    final fees = await _feeRows(null, []);
    return AdminStats(
      students: await count('SELECT COUNT(*) FROM students'),
      faculty: await count('SELECT COUNT(*) FROM faculty'),
      courses: await count('SELECT COUNT(*) FROM courses'),
      pendingRequests:
          await count("SELECT COUNT(*) FROM requests WHERE status = 'Pending'"),
      upcomingEvents:
          await count('SELECT COUNT(*) FROM events WHERE date >= ?', [today]),
      feesCollected: fees.fold<int>(0, (a, f) => a + f.paid),
      feesPending: fees.fold<int>(0, (a, f) => a + f.pending),
      attendancePct: attendancePct,
      attendanceTrend: trend,
      studentsPerProgram: perProgram,
    );
  }

  @override
  Future<List<Activity>> recentActivities({int limit = 6}) async {
    final db = await _d;
    final rows =
        await db.query('activity_log', orderBy: 'id DESC', limit: limit);
    return rows.map(Activity.fromMap).toList();
  }

  String _grade(double pct) {
    if (pct >= 85) return 'A+';
    if (pct >= 75) return 'A';
    if (pct >= 60) return 'B';
    if (pct >= 40) return 'C';
    return 'F';
  }

  @override
  Future<ReportData> report(ReportType type,
      {String? program, int? semester}) async {
    final db = await _d;
    switch (type) {
      case ReportType.attendance:
        final list = await attendanceOverview(program: program, semester: semester);
        return ReportData(
          title: 'Student Attendance Report',
          columns: const [
            'Student ID', 'Name', 'Program', 'Sem', 'Attended', 'Total', 'Attendance'
          ],
          rows: list
              .map((s) => [
                    s.code,
                    s.name,
                    s.program,
                    '${s.semester}',
                    '${s.attended}',
                    '${s.total}',
                    '${s.pct.toStringAsFixed(1)}%',
                  ])
              .toList(),
        );
      case ReportType.fees:
        var list = await allFeeSummaries();
        if (program != null) list = list.where((f) => f.student.program == program).toList();
        if (semester != null) list = list.where((f) => f.student.semester == semester).toList();
        return ReportData(
          title: 'Fees Report',
          columns: const [
            'Student ID', 'Name', 'Program', 'Sem', 'Total', 'Paid', 'Pending', 'Status'
          ],
          rows: list
              .map((f) => [
                    f.student.studentId,
                    f.student.name,
                    f.student.program,
                    '${f.student.semester}',
                    Fmt.rs(f.total),
                    Fmt.rs(f.paid),
                    Fmt.rs(f.pending),
                    f.status,
                  ])
              .toList(),
        );
      case ReportType.courses:
        final where = <String>[];
        final args = <Object?>[];
        if (program != null) {
          where.add('c.program = ?');
          args.add(program);
        }
        if (semester != null) {
          where.add('c.semester = ?');
          args.add(semester);
        }
        final rows = await db.rawQuery(
            "SELECT c.code, c.name, c.program, c.semester, c.credits, COALESCE(f.name, 'Unassigned') AS faculty, "
            '(SELECT COUNT(*) FROM students s WHERE s.program = c.program AND s.semester = c.semester) AS enrolled, '
            '(SELECT COUNT(*) FROM attendance a WHERE a.course_id = c.id) AS total, '
            "(SELECT COUNT(*) FROM attendance a WHERE a.course_id = c.id AND a.status IN ('present','late')) AS attended "
            'FROM courses c LEFT JOIN faculty f ON f.id = c.faculty_id '
            '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
            'ORDER BY c.program, c.semester, c.code',
            args);
        return ReportData(
          title: 'Courses Report',
          columns: const [
            'Code', 'Course', 'Program', 'Sem', 'Credits', 'Faculty', 'Enrolled', 'Avg attendance'
          ],
          rows: rows
              .map((m) => [
                    m['code'] as String,
                    m['name'] as String,
                    m['program'] as String,
                    '${_n(m['semester'])}',
                    '${_n(m['credits'])}',
                    m['faculty'] as String,
                    '${_n(m['enrolled'])}',
                    '${attendancePercent(_n(m['attended']), _n(m['total'])).toStringAsFixed(1)}%',
                  ])
              .toList(),
        );
      case ReportType.performance:
        final where = <String>[];
        final args = <Object?>[];
        if (program != null) {
          where.add('s.program = ?');
          args.add(program);
        }
        if (semester != null) {
          where.add('s.semester = ?');
          args.add(semester);
        }
        final rows = await db.rawQuery(
            'SELECT s.student_id AS code, s.name AS name, s.program AS program, s.semester AS semester, '
            'COUNT(m.id) AS exams, SUM(m.score) AS score, SUM(m.max_score) AS max_score '
            'FROM students s LEFT JOIN marks m ON m.student_id = s.id '
            '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
            'GROUP BY s.id ORDER BY s.name COLLATE NOCASE',
            args);
        return ReportData(
          title: 'Student Performance Report',
          columns: const [
            'Student ID', 'Name', 'Program', 'Sem', 'Exams', 'Score', 'Percentage', 'Grade'
          ],
          rows: rows.map((m) {
            final max = _n(m['max_score']);
            final pct = max == 0 ? 0.0 : _n(m['score']) * 100 / max;
            return [
              m['code'] as String,
              m['name'] as String,
              m['program'] as String,
              '${_n(m['semester'])}',
              '${_n(m['exams'])}',
              '${_n(m['score'])} / $max',
              '${pct.toStringAsFixed(1)}%',
              max == 0 ? '-' : _grade(pct),
            ];
          }).toList(),
        );
      case ReportType.faculty:
        final rows = await db.rawQuery(
            'SELECT f.name, f.department, f.designation, f.email, '
            '(SELECT COUNT(*) FROM courses c WHERE c.faculty_id = f.id) AS courses, '
            '(SELECT COUNT(*) FROM timetable t WHERE t.faculty_id = f.id) AS sessions '
            'FROM faculty f ORDER BY f.name COLLATE NOCASE');
        return ReportData(
          title: 'Faculty Report',
          columns: const [
            'Name', 'Department', 'Designation', 'Email', 'Courses', 'Weekly sessions'
          ],
          rows: rows
              .map((m) => [
                    m['name'] as String,
                    m['department'] as String,
                    m['designation'] as String,
                    m['email'] as String,
                    '${_n(m['courses'])}',
                    '${_n(m['sessions'])}',
                  ])
              .toList(),
        );
    }
  }
}
