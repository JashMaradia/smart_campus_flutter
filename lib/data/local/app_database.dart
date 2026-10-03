import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_campus/data/local/seed_data.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the local SQLite database, creates the schema and seeds demo data on
/// first launch. Bump [schemaVersion] and extend [_migrate] for future updates
/// so users never lose data.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _fileName = 'smart_campus.db';
  static const int schemaVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await SeedData.insert(db);
      },
      onUpgrade: _migrate,
    );
  }

  /// Add `if (oldVersion < 2) { ... }` blocks here when the schema changes.
  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {}

  Future<void> _createTables(Database db) async {
    const statements = <String>[
      '''CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        login_id TEXT NOT NULL UNIQUE COLLATE NOCASE,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        dob TEXT,
        created_at TEXT NOT NULL)''',
      '''CREATE TABLE students(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        student_id TEXT NOT NULL UNIQUE COLLATE NOCASE,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        department TEXT NOT NULL,
        program TEXT NOT NULL,
        semester INTEGER NOT NULL,
        photo_path TEXT,
        address TEXT NOT NULL DEFAULT '',
        dob TEXT NOT NULL)''',
      '''CREATE TABLE faculty(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        department TEXT NOT NULL,
        designation TEXT NOT NULL)''',
      '''CREATE TABLE courses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE COLLATE NOCASE,
        name TEXT NOT NULL,
        program TEXT NOT NULL,
        semester INTEGER NOT NULL,
        credits INTEGER NOT NULL,
        faculty_id INTEGER REFERENCES faculty(id) ON DELETE SET NULL,
        description TEXT NOT NULL DEFAULT '')''',
      '''CREATE TABLE course_materials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        added_on TEXT NOT NULL)''',
      '''CREATE TABLE timetable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
        faculty_id INTEGER REFERENCES faculty(id) ON DELETE SET NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT NOT NULL)''',
      '''CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
        course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        UNIQUE(student_id, course_id, date))''',
      'CREATE INDEX idx_att_student ON attendance(student_id)',
      'CREATE INDEX idx_att_course_date ON attendance(course_id, date)',
      '''CREATE TABLE marks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
        course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
        exam TEXT NOT NULL,
        score INTEGER NOT NULL,
        max_score INTEGER NOT NULL)''',
      '''CREATE TABLE notices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        category TEXT NOT NULL,
        published_on TEXT NOT NULL,
        is_published INTEGER NOT NULL DEFAULT 1)''',
      '''CREATE TABLE events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location TEXT NOT NULL)''',
      '''CREATE TABLE fee_structures(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        program TEXT NOT NULL,
        semester INTEGER NOT NULL,
        total_amount INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        UNIQUE(program, semester))''',
      '''CREATE TABLE fee_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
        amount INTEGER NOT NULL,
        paid_on TEXT NOT NULL,
        method TEXT NOT NULL,
        receipt_no TEXT NOT NULL)''',
      '''CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0)''',
      '''CREATE TABLE activity_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL)''',
      '''CREATE TABLE requests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        details TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Pending',
        created_at TEXT NOT NULL)''',
      '''CREATE TABLE app_settings(
        name TEXT PRIMARY KEY,
        value TEXT NOT NULL)''',
    ];
    for (final s in statements) {
      await db.execute(s);
    }
  }

  /// Copies the database file to a temp location and returns that path.
  Future<String> backupToTemp() async {
    final db = await database;
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}
    final dir = await getTemporaryDirectory();
    final dest = join(dir.path,
        'smart_campus_backup_${DateTime.now().millisecondsSinceEpoch}.db');
    await File(db.path).copy(dest);
    return dest;
  }

  /// Replaces the current database with [filePath] after checking it is SQLite.
  Future<void> restoreFrom(String filePath) async {
    final header = await File(filePath).openRead(0, 15).first;
    final text = String.fromCharCodes(header);
    if (text != 'SQLite format 3') {
      throw const FormatException('This file is not a valid Smart Campus backup.');
    }
    final db = await database;
    final path = db.path;
    await db.close();
    _db = null;
    await File(filePath).copy(path);
    await database;
  }

  /// Deletes everything and re-creates the demo data.
  Future<void> resetDemoData() async {
    final db = await database;
    final path = db.path;
    await db.close();
    _db = null;
    await deleteDatabase(path);
    await database;
  }
}
