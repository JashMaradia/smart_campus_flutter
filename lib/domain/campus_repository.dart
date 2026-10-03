import 'package:smart_campus/data/models/models.dart';

/// The only data contract the UI depends on. To move to a real backend later,
/// write a class (for example `ApiCampusRepository`) that implements this and
/// swap it in `main.dart`. No screen needs to change.
abstract class CampusRepository {
  // ---- settings ----
  Future<String?> getSetting(String name);
  Future<void> setSetting(String name, String value);

  // ---- auth ----
  Future<AppUser?> findUser(String loginId);
  Future<AppUser?> getUser(int id);
  Future<bool> verifyPassword(AppUser user, String password);
  Future<void> changePassword(int userId, String newPassword);
  Future<String?> activateStudentAccount({
    required String studentId,
    required String email,
    required String password,
  });
  Future<AppUser?> verifyRecovery({
    required String loginId,
    required String email,
    required DateTime dob,
  });
  Future<void> updateUserProfile(int userId,
      {required String name, required String phone});

  // ---- students ----
  Future<List<Student>> students(
      {String query = '', String? program, int? semester});
  Future<Student?> studentById(int id);
  Future<Student?> studentByUserId(int userId);

  /// Returns an error message, or null on success.
  Future<String?> saveStudent(Student s, {bool createAccount = false});
  Future<void> deleteStudent(int id);
  Future<void> updateStudentSelf(int id,
      {required String phone, required String address, String? photoPath});

  // ---- faculty ----
  Future<List<Faculty>> faculty();
  Future<void> saveFaculty(Faculty f);
  Future<void> deleteFaculty(int id);
  Future<void> assignCourses(int facultyId, Set<int> courseIds);

  // ---- courses ----
  Future<List<Course>> courses({String? program, int? semester});
  Future<List<Course>> coursesForStudent(Student s);
  Future<String?> saveCourse(Course c);
  Future<void> deleteCourse(int id);
  Future<List<CourseMaterial>> materials(int courseId);
  Future<void> addMaterial(int courseId, String title, String path);
  Future<void> deleteMaterial(int id);

  // ---- timetable ----
  Future<List<TimetableEntry>> timetable(
      {String? program, int? semester, int? day});
  Future<List<TimetableEntry>> timetableForStudent(Student s);

  /// Returns a clash/validation message, or null on success.
  Future<String?> saveTimetable(TimetableEntry e);
  Future<void> deleteTimetable(int id);

  // ---- attendance ----
  Future<List<AttendanceMark>> attendanceSheet(int courseId, DateTime date);
  Future<void> saveAttendance(
      int courseId, DateTime date, Map<int, String> statuses);
  Future<List<SubjectAttendance>> subjectAttendance(int studentId);
  Future<List<AttendanceEntry>> attendanceHistory(int studentId,
      {int? courseId});
  Future<List<StudentAttendanceSummary>> attendanceOverview({
    String? program,
    int? semester,
    int? courseId,
    String query = '',
  });

  // ---- notices & events ----
  Future<List<Notice>> notices(
      {bool publishedOnly = false, String? category, String query = ''});
  Future<void> saveNotice(Notice n);
  Future<void> deleteNotice(int id);
  Future<List<EventItem>> events({bool? upcoming});
  Future<void> saveEvent(EventItem e);
  Future<void> deleteEvent(int id);

  // ---- fees ----
  Future<List<FeeStructure>> feeStructures();
  Future<void> saveFeeStructure(FeeStructure f);
  Future<FeeSummary> feeSummary(Student s);
  Future<List<FeeSummary>> allFeeSummaries({String query = '', String? status});
  Future<List<Payment>> payments(int studentId);
  Future<Payment> recordPayment(int studentId, int amount, String method);

  // ---- notifications ----
  Future<List<AppNotification>> notifications(int userId);
  Future<int> unreadCount(int userId);
  Future<void> markRead(int id);
  Future<void> markAllRead(int userId);
  Future<void> refreshStudentAlerts(Student s);

  // ---- requests ----
  Future<List<CampusRequest>> requests({int? studentId, String? status});
  Future<void> createRequest(int studentId, String type, String details);
  Future<void> setRequestStatus(int id, String status);

  // ---- dashboard & reports ----
  Future<AdminStats> adminStats();
  Future<List<Activity>> recentActivities({int limit = 6});
  Future<ReportData> report(ReportType type, {String? program, int? semester});
}
