import 'package:smart_campus/core/utils.dart';

typedef DbRow = Map<String, Object?>;

String _s(Object? v) => (v as String?) ?? '';
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class AppUser {
  final int id;
  final String loginId, email, name, phone, role, passwordHash, salt;
  final String? dob;
  const AppUser({
    required this.id,
    required this.loginId,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.passwordHash,
    required this.salt,
    this.dob,
  });
  factory AppUser.fromMap(DbRow m) => AppUser(
        id: _i(m['id']),
        loginId: _s(m['login_id']),
        email: _s(m['email']),
        name: _s(m['name']),
        phone: _s(m['phone']),
        role: _s(m['role']),
        passwordHash: _s(m['password_hash']),
        salt: _s(m['salt']),
        dob: m['dob'] as String?,
      );
}

class Student {
  final int? id;
  final int? userId;
  final String studentId, name, email, phone, department, program, address, dob;
  final int semester;
  final String? photoPath;
  const Student({
    this.id,
    this.userId,
    required this.studentId,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.program,
    required this.semester,
    this.photoPath,
    this.address = '',
    required this.dob,
  });
  factory Student.fromMap(DbRow m) => Student(
        id: _i(m['id']),
        userId: m['user_id'] as int?,
        studentId: _s(m['student_id']),
        name: _s(m['name']),
        email: _s(m['email']),
        phone: _s(m['phone']),
        department: _s(m['department']),
        program: _s(m['program']),
        semester: _i(m['semester']),
        photoPath: m['photo_path'] as String?,
        address: _s(m['address']),
        dob: _s(m['dob']),
      );
  DbRow toMap() => {
        'student_id': studentId,
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'program': program,
        'semester': semester,
        'photo_path': photoPath,
        'address': address,
        'dob': dob,
      };
  bool get hasAccount => userId != null;
  DateTime get dobDate => DateTime.tryParse(dob) ?? DateTime(2004, 1, 1);
}

class Faculty {
  final int? id;
  final String name, email, phone, department, designation;
  const Faculty({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
  });
  factory Faculty.fromMap(DbRow m) => Faculty(
        id: _i(m['id']),
        name: _s(m['name']),
        email: _s(m['email']),
        phone: _s(m['phone']),
        department: _s(m['department']),
        designation: _s(m['designation']),
      );
  DbRow toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'designation': designation,
      };
}

class Course {
  final int? id;
  final String code, name, program, description;
  final int semester, credits;
  final int? facultyId;
  final String? facultyName;
  const Course({
    this.id,
    required this.code,
    required this.name,
    required this.program,
    required this.semester,
    required this.credits,
    this.facultyId,
    this.description = '',
    this.facultyName,
  });
  factory Course.fromMap(DbRow m) => Course(
        id: _i(m['id']),
        code: _s(m['code']),
        name: _s(m['name']),
        program: _s(m['program']),
        semester: _i(m['semester']),
        credits: _i(m['credits']),
        facultyId: m['faculty_id'] as int?,
        description: _s(m['description']),
        facultyName: m['faculty_name'] as String?,
      );
  DbRow toMap() => {
        'code': code,
        'name': name,
        'program': program,
        'semester': semester,
        'credits': credits,
        'faculty_id': facultyId,
        'description': description,
      };
}

class CourseMaterial {
  final int id, courseId;
  final String title, filePath;
  final DateTime addedOn;
  const CourseMaterial({
    required this.id,
    required this.courseId,
    required this.title,
    required this.filePath,
    required this.addedOn,
  });
  factory CourseMaterial.fromMap(DbRow m) => CourseMaterial(
        id: _i(m['id']),
        courseId: _i(m['course_id']),
        title: _s(m['title']),
        filePath: _s(m['file_path']),
        addedOn: DateTime.tryParse(_s(m['added_on'])) ?? DateTime.now(),
      );
}

class TimetableEntry {
  final int? id;
  final int courseId;
  final int? facultyId;
  final int day; // 1 = Monday ... 6 = Saturday
  final String start, end, room;
  final String courseCode, courseName, facultyName, program;
  final int semester;
  const TimetableEntry({
    this.id,
    required this.courseId,
    this.facultyId,
    required this.day,
    required this.start,
    required this.end,
    required this.room,
    this.courseCode = '',
    this.courseName = '',
    this.facultyName = '',
    this.program = '',
    this.semester = 0,
  });
  factory TimetableEntry.fromMap(DbRow m) => TimetableEntry(
        id: _i(m['id']),
        courseId: _i(m['course_id']),
        facultyId: m['faculty_id'] as int?,
        day: _i(m['day_of_week']),
        start: _s(m['start_time']),
        end: _s(m['end_time']),
        room: _s(m['room']),
        courseCode: _s(m['course_code']),
        courseName: _s(m['course_name']),
        facultyName: m['faculty_name'] as String? ?? 'Unassigned',
        program: _s(m['program']),
        semester: _i(m['semester']),
      );
  DbRow toMap() => {
        'course_id': courseId,
        'faculty_id': facultyId,
        'day_of_week': day,
        'start_time': start,
        'end_time': end,
        'room': room,
      };
}

class AttendanceMark {
  final int studentPk;
  final String code, name;
  final String? status;
  const AttendanceMark({
    required this.studentPk,
    required this.code,
    required this.name,
    this.status,
  });
}

class AttendanceEntry {
  final DateTime date;
  final String courseName, status;
  const AttendanceEntry({
    required this.date,
    required this.courseName,
    required this.status,
  });
}

class SubjectAttendance {
  final int courseId, present, late, absent, total;
  final String code, name;
  const SubjectAttendance({
    required this.courseId,
    required this.code,
    required this.name,
    required this.present,
    required this.late,
    required this.absent,
    required this.total,
  });
  int get attended => present + late;
  double get pct => attendancePercent(attended, total);
}

class StudentAttendanceSummary {
  final int studentPk, attended, total, semester;
  final String code, name, program;
  const StudentAttendanceSummary({
    required this.studentPk,
    required this.code,
    required this.name,
    required this.program,
    required this.semester,
    required this.attended,
    required this.total,
  });
  double get pct => attendancePercent(attended, total);
}

class Notice {
  final int? id;
  final String title, body, category;
  final DateTime publishedOn;
  final bool isPublished;
  const Notice({
    this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.publishedOn,
    required this.isPublished,
  });
  factory Notice.fromMap(DbRow m) => Notice(
        id: _i(m['id']),
        title: _s(m['title']),
        body: _s(m['body']),
        category: _s(m['category']),
        publishedOn: DateTime.tryParse(_s(m['published_on'])) ?? DateTime.now(),
        isPublished: _i(m['is_published']) == 1,
      );
  DbRow toMap() => {
        'title': title,
        'body': body,
        'category': category,
        'published_on': Fmt.dbDate(publishedOn),
        'is_published': isPublished ? 1 : 0,
      };
  Notice copyWith({bool? isPublished}) => Notice(
        id: id,
        title: title,
        body: body,
        category: category,
        publishedOn: publishedOn,
        isPublished: isPublished ?? this.isPublished,
      );
}

class EventItem {
  final int? id;
  final String title, description, startTime, endTime, location;
  final DateTime date;
  const EventItem({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
  });
  factory EventItem.fromMap(DbRow m) => EventItem(
        id: _i(m['id']),
        title: _s(m['title']),
        description: _s(m['description']),
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
        startTime: _s(m['start_time']),
        endTime: _s(m['end_time']),
        location: _s(m['location']),
      );
  DbRow toMap() => {
        'title': title,
        'description': description,
        'date': Fmt.dbDate(date),
        'start_time': startTime,
        'end_time': endTime,
        'location': location,
      };
}

class FeeStructure {
  final int? id;
  final String program;
  final int semester, totalAmount;
  final DateTime dueDate;
  const FeeStructure({
    this.id,
    required this.program,
    required this.semester,
    required this.totalAmount,
    required this.dueDate,
  });
  factory FeeStructure.fromMap(DbRow m) => FeeStructure(
        id: _i(m['id']),
        program: _s(m['program']),
        semester: _i(m['semester']),
        totalAmount: _i(m['total_amount']),
        dueDate: DateTime.tryParse(_s(m['due_date'])) ?? DateTime.now(),
      );
}

class FeeSummary {
  final Student student;
  final int total, paid;
  final DateTime? dueDate;
  const FeeSummary({
    required this.student,
    required this.total,
    required this.paid,
    this.dueDate,
  });
  int get pending => total - paid > 0 ? total - paid : 0;
  String get status {
    if (total > 0 && paid >= total) return 'Paid';
    if (paid > 0) return 'Partial';
    return 'Due';
  }
}

class Payment {
  final int id, studentId, amount;
  final DateTime paidOn;
  final String method, receiptNo;
  const Payment({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.paidOn,
    required this.method,
    required this.receiptNo,
  });
  factory Payment.fromMap(DbRow m) => Payment(
        id: _i(m['id']),
        studentId: _i(m['student_id']),
        amount: _i(m['amount']),
        paidOn: DateTime.tryParse(_s(m['paid_on'])) ?? DateTime.now(),
        method: _s(m['method']),
        receiptNo: _s(m['receipt_no']),
      );
}

class AppNotification {
  final int id, userId;
  final String type, title, message;
  final DateTime createdAt;
  final bool isRead;
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });
  factory AppNotification.fromMap(DbRow m) => AppNotification(
        id: _i(m['id']),
        userId: _i(m['user_id']),
        type: _s(m['type']),
        title: _s(m['title']),
        message: _s(m['message']),
        createdAt: DateTime.tryParse(_s(m['created_at'])) ?? DateTime.now(),
        isRead: _i(m['is_read']) == 1,
      );
}

class Activity {
  final String message;
  final DateTime createdAt;
  const Activity({required this.message, required this.createdAt});
  factory Activity.fromMap(DbRow m) => Activity(
        message: _s(m['message']),
        createdAt: DateTime.tryParse(_s(m['created_at'])) ?? DateTime.now(),
      );
}

class CampusRequest {
  final int id, studentId;
  final String studentName, studentCode, type, details, status;
  final DateTime createdAt;
  const CampusRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.type,
    required this.details,
    required this.status,
    required this.createdAt,
  });
  factory CampusRequest.fromMap(DbRow m) => CampusRequest(
        id: _i(m['id']),
        studentId: _i(m['student_id']),
        studentName: _s(m['student_name']),
        studentCode: _s(m['student_code']),
        type: _s(m['type']),
        details: _s(m['details']),
        status: _s(m['status']),
        createdAt: DateTime.tryParse(_s(m['created_at'])) ?? DateTime.now(),
      );
}

enum ReportType { attendance, fees, courses, performance, faculty }

class ReportData {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  const ReportData({
    required this.title,
    required this.columns,
    required this.rows,
  });
}

class AdminStats {
  final int students, faculty, courses, pendingRequests, upcomingEvents;
  final int feesCollected, feesPending;
  final double attendancePct;
  final List<double> attendanceTrend;
  final Map<String, int> studentsPerProgram;
  const AdminStats({
    required this.students,
    required this.faculty,
    required this.courses,
    required this.pendingRequests,
    required this.upcomingEvents,
    required this.feesCollected,
    required this.feesPending,
    required this.attendancePct,
    required this.attendanceTrend,
    required this.studentsPerProgram,
  });
}
