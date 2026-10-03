import 'dart:math';

import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:sqflite/sqflite.dart';

/// Demo data inserted on first launch so the app never looks empty.
/// Dates are relative to the day the app is first opened.
class SeedData {
  static Future<void> insert(Database db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String d(DateTime t) => Fmt.dbDate(t);
    String iso(DateTime t) => t.toIso8601String();

    Future<int> addUser({
      required String loginId,
      required String email,
      required String name,
      required String phone,
      required String role,
      required String password,
      required String dob,
    }) {
      final salt = PasswordHasher.newSalt();
      return db.insert('users', {
        'login_id': loginId,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'password_hash': PasswordHasher.hash(password, salt),
        'salt': salt,
        'dob': dob,
        'created_at': iso(now),
      });
    }

    // ---- Admin ----
    await addUser(
      loginId: AppStrings.adminEmail,
      email: AppStrings.adminEmail,
      name: 'Campus Admin',
      phone: '9876543210',
      role: 'admin',
      password: AppStrings.adminPassword,
      dob: '1985-06-15',
    );

    // ---- Faculty ----
    const facultyDefs = [
      ['Prof. Rajesh Kulkarni', 'Computer Science', 'Professor'],
      ['Prof. Sunita Desai', 'Computer Science', 'Associate Professor'],
      ['Dr. Anil Joshi', 'Mathematics', 'Assistant Professor'],
      ['Prof. Neha Kapoor', 'Computer Science', 'Assistant Professor'],
      ['Dr. Priya Rao', 'Electronics', 'Professor'],
      ['Prof. Manoj Gupta', 'Mechanical', 'Associate Professor'],
    ];
    final facultyIds = <int>[];
    for (var i = 0; i < facultyDefs.length; i++) {
      final f = facultyDefs[i];
      facultyIds.add(await db.insert('faculty', {
        'name': f[0],
        'email': '${f[0].toLowerCase().replaceAll('prof. ', '').replaceAll('dr. ', '').replaceAll(' ', '.')}@smartcampus.edu',
        'phone': '97${(10000000 + i * 123457)}',
        'department': f[1],
        'designation': f[2],
      }));
    }

    // ---- Courses (code, name, program, semester, credits, facultyIndex) ----
    const courseDefs = [
      ['CS301', 'Data Structures', 'B.Tech CSE', 3, 4, 0],
      ['CS302', 'Database Systems', 'B.Tech CSE', 3, 4, 1],
      ['CS303', 'Mathematics III', 'B.Tech CSE', 3, 3, 2],
      ['CS304', 'Operating Systems', 'B.Tech CSE', 3, 4, 3],
      ['CS501', 'Computer Networks', 'B.Tech CSE', 5, 4, 1],
      ['CS502', 'Software Engineering', 'B.Tech CSE', 5, 3, 0],
      ['EC301', 'Digital Electronics', 'B.Tech ECE', 3, 4, 4],
      ['EC302', 'Signals and Systems', 'B.Tech ECE', 3, 3, 2],
      ['EC303', 'Network Analysis', 'B.Tech ECE', 3, 3, 4],
      ['ME301', 'Thermodynamics', 'B.Tech Mechanical', 3, 4, 5],
      ['ME302', 'Fluid Mechanics', 'B.Tech Mechanical', 3, 4, 5],
      ['ME303', 'Mechanics of Materials', 'B.Tech Mechanical', 3, 3, 5],
    ];
    final courseIds = <int>[];
    for (final c in courseDefs) {
      courseIds.add(await db.insert('courses', {
        'code': c[0],
        'name': c[1],
        'program': c[2],
        'semester': c[3],
        'credits': c[4],
        'faculty_id': facultyIds[c[5] as int],
        'description':
            '${c[1]} covers the core concepts, problem solving and lab practice expected in semester ${c[3]} of ${c[2]}.',
      }));
    }

    // ---- Students (code, name, program, semester, hasAccount) ----
    const studentDefs = [
      ['CS2301', 'Aarav Mehta', 'B.Tech CSE', 3, true],
      ['CS2302', 'Ananya Singh', 'B.Tech CSE', 3, true],
      ['CS2303', 'Vivaan Shah', 'B.Tech CSE', 3, true],
      ['CS2304', 'Isha Desai', 'B.Tech CSE', 3, true],
      ['CS2305', 'Kunal Verma', 'B.Tech CSE', 3, true],
      ['CS2306', 'Riya Nair', 'B.Tech CSE', 3, true],
      ['CS2307', 'Arjun Reddy', 'B.Tech CSE', 3, true],
      ['CS2308', 'Meera Joshi', 'B.Tech CSE', 3, true],
      ['CS2201', 'Rahul Sharma', 'B.Tech CSE', 5, true],
      ['CS2202', 'Sneha Kapoor', 'B.Tech CSE', 5, true],
      ['CS2203', 'Tanvi Bhatt', 'B.Tech CSE', 5, true],
      ['EC2301', 'Diya Patel', 'B.Tech ECE', 3, true],
      ['EC2302', 'Harsh Trivedi', 'B.Tech ECE', 3, true],
      ['EC2303', 'Pooja Menon', 'B.Tech ECE', 3, true],
      ['EC2304', 'Siddharth Rao', 'B.Tech ECE', 3, true],
      ['EC2305', 'Nidhi Agarwal', 'B.Tech ECE', 3, false],
      ['ME2301', 'Rohan Iyer', 'B.Tech Mechanical', 3, true],
      ['ME2302', 'Kabir Khan', 'B.Tech Mechanical', 3, true],
      ['ME2303', 'Aditya Pandey', 'B.Tech Mechanical', 3, true],
      ['ME2304', 'Simran Kaur', 'B.Tech Mechanical', 3, false],
    ];
    final studentPks = <int>[];
    final studentUserIds = <int?>[];
    for (var i = 0; i < studentDefs.length; i++) {
      final s = studentDefs[i];
      final code = s[0] as String;
      final name = s[1] as String;
      final program = s[2] as String;
      final email = '${name.toLowerCase().replaceAll(' ', '.')}@smartcampus.edu';
      final phone = '98${25010000 + i * 7919}';
      final dob = d(DateTime(2004 + (i % 3), 1 + (i % 12), 5 + (i % 20)));
      int? uid;
      if (s[4] == true) {
        uid = await addUser(
          loginId: code,
          email: email,
          name: name,
          phone: phone,
          role: 'student',
          password: AppStrings.defaultStudentPassword,
          dob: dob,
        );
      }
      studentUserIds.add(uid);
      studentPks.add(await db.insert('students', {
        'user_id': uid,
        'student_id': code,
        'name': name,
        'email': email,
        'phone': phone,
        'department': kPrograms[program],
        'program': program,
        'semester': s[3],
        'address': 'Block ${String.fromCharCode(65 + i % 4)}-${100 + i}, Campus Road',
        'dob': dob,
      }));
    }

    // ---- Timetable (clash free: class, faculty and room) ----
    const slots = [
      ['09:00', '10:00'],
      ['10:00', '11:00'],
      ['11:15', '12:15'],
      ['13:00', '14:00'],
      ['14:00', '15:00'],
    ];
    const rooms = {
      'B.Tech CSE|3': 'Room 204',
      'B.Tech CSE|5': 'Room 305',
      'B.Tech ECE|3': 'Room 112',
      'B.Tech Mechanical|3': 'Room 118',
    };
    final used = <String>{};
    final courseDays = <int, Set<int>>{};
    for (var ci = 0; ci < courseDefs.length; ci++) {
      final c = courseDefs[ci];
      final fid = facultyIds[c[5] as int];
      courseDays[ci] = <int>{};
      for (var j = 0; j < 3; j++) {
        var cell = (ci * 7 + j * 11) % 30;
        for (var tries = 0; tries < 30; tries++, cell = (cell + 1) % 30) {
          final day = cell ~/ 5 + 1;
          final slot = cell % 5;
          final groupKey = 'g|${c[2]}|${c[3]}|$day|$slot';
          final facKey = 'f|$fid|$day|$slot';
          if (used.contains(groupKey) ||
              used.contains(facKey) ||
              courseDays[ci]!.contains(day)) {
            continue;
          }
          used
            ..add(groupKey)
            ..add(facKey);
          courseDays[ci]!.add(day);
          await db.insert('timetable', {
            'course_id': courseIds[ci],
            'faculty_id': fid,
            'day_of_week': day,
            'start_time': slots[slot][0],
            'end_time': slots[slot][1],
            'room': rooms['${c[2]}|${c[3]}'] ?? 'Room 101',
          });
          break;
        }
      }
    }

    // ---- Attendance (last 6 weeks) and marks ----
    final rng = Random(7);
    const baseProb = [0.94, 0.9, 0.86, 0.96, 0.8, 0.92, 0.88, 0.72, 0.95, 0.84];
    final batch = db.batch();
    final special = <String, int>{};
    for (var back = 1; back <= 42; back++) {
      final date = today.subtract(Duration(days: back));
      if (date.weekday == 7) continue;
      for (var ci = 0; ci < courseDefs.length; ci++) {
        if (!courseDays[ci]!.contains(date.weekday)) continue;
        final c = courseDefs[ci];
        for (var si = 0; si < studentDefs.length; si++) {
          final s = studentDefs[si];
          if (s[2] != c[2] || s[3] != c[3]) continue;
          String status;
          if (s[0] == 'CS2301' && c[0] == 'CS303') {
            // Deliberately low so the 75% warning shows in the demo.
            final n = (special['k'] ?? 0) + 1;
            special['k'] = n;
            status = n % 3 == 0 ? 'absent' : 'present';
          } else {
            final r = rng.nextDouble();
            status = r < baseProb[si % baseProb.length]
                ? 'present'
                : (rng.nextDouble() < 0.2 ? 'late' : 'absent');
          }
          batch.insert('attendance', {
            'student_id': studentPks[si],
            'course_id': courseIds[ci],
            'date': d(date),
            'status': status,
          });
        }
      }
    }
    await batch.commit(noResult: true);

    final marksBatch = db.batch();
    for (var si = 0; si < studentDefs.length; si++) {
      for (var ci = 0; ci < courseDefs.length; ci++) {
        final s = studentDefs[si];
        final c = courseDefs[ci];
        if (s[2] != c[2] || s[3] != c[3]) continue;
        marksBatch.insert('marks', {
          'student_id': studentPks[si],
          'course_id': courseIds[ci],
          'exam': 'Internal Test 1',
          'score': 24 + rng.nextInt(25),
          'max_score': 50,
        });
        marksBatch.insert('marks', {
          'student_id': studentPks[si],
          'course_id': courseIds[ci],
          'exam': 'Mid-Semester',
          'score': 45 + rng.nextInt(50),
          'max_score': 100,
        });
      }
    }
    await marksBatch.commit(noResult: true);

    // ---- Fees ----
    const feeDefs = [
      ['B.Tech CSE', 3, 85000],
      ['B.Tech CSE', 5, 90000],
      ['B.Tech ECE', 3, 80000],
      ['B.Tech Mechanical', 3, 78000],
    ];
    final due = today.add(const Duration(days: 12));
    for (final f in feeDefs) {
      await db.insert('fee_structures', {
        'program': f[0],
        'semester': f[1],
        'total_amount': f[2],
        'due_date': d(due),
      });
    }
    var receipt = 1001;
    Future<void> pay(int pk, int amount, int daysAgo, String method) async {
      await db.insert('fee_payments', {
        'student_id': pk,
        'amount': amount,
        'paid_on': d(today.subtract(Duration(days: daysAgo))),
        'method': method,
        'receipt_no': 'R-${receipt++}',
      });
    }

    for (var si = 0; si < studentDefs.length; si++) {
      final s = studentDefs[si];
      final total =
          feeDefs.firstWhere((f) => f[0] == s[2] && f[1] == s[3])[2] as int;
      if (s[0] == 'CS2301') {
        await pay(studentPks[si], 40000, 82, 'UPI');
        await pay(studentPks[si], 32500, 46, 'Bank transfer');
        continue;
      }
      switch (si % 4) {
        case 0:
          final first = (total * 0.6).round();
          await pay(studentPks[si], first, 85, 'UPI');
          await pay(studentPks[si], total - first, 40, 'Card');
          break;
        case 1:
          await pay(studentPks[si], (total * 0.5).round(), 60, 'Cash');
          break;
        case 2:
          await pay(studentPks[si], (total * 0.8).round(), 55, 'UPI');
          break;
        default:
          break; // nothing paid yet
      }
    }

    // ---- Notices ----
    const noticeDefs = [
      ['Mid-semester exam timetable released', 'Exam', 1, 1,
          'The mid-semester examination timetable for all programs is now available. Students must carry their ID cards and hall tickets. Exams begin in two weeks.'],
      ['Fee payment last date approaching', 'Urgent', 2, 1,
          'The last date to pay the current semester fees is 12 days from today. Late payments will attract a fine as per college rules.'],
      ['Library timings extended during exams', 'General', 3, 1,
          'The central library will remain open from 8:00 AM to 9:00 PM during the examination period. Reading hall seats are first come first served.'],
      ['Annual Tech Fest registrations open', 'Event', 5, 1,
          'Registrations for the Annual Tech Fest are now open. Teams of up to four students can participate in coding, robotics and design contests.'],
      ['Scholarship applications open', 'General', 8, 1,
          'Merit and need based scholarship applications are open until the end of the month. Submit the form at the administrative office with income proof.'],
      ['Convocation rehearsal schedule (draft)', 'General', 0, 0,
          'Draft schedule for the convocation rehearsal. This notice will be published after approval.'],
    ];
    for (final n in noticeDefs) {
      await db.insert('notices', {
        'title': n[0],
        'category': n[1],
        'published_on': d(today.subtract(Duration(days: n[2] as int))),
        'is_published': n[3],
        'body': n[4],
      });
    }

    // ---- Events ----
    const eventDefs = [
      ['Guest Lecture: AI in Industry', 5, '11:00', '12:30', 'Seminar Hall A',
          'An industry expert from a leading technology company talks about real world uses of artificial intelligence.'],
      ['Annual Tech Fest', 15, '10:00', '17:00', 'Main Auditorium',
          'A full day of coding contests, project exhibitions, robotics demos and workshops.'],
      ['Inter-college Sports Meet', 22, '08:00', '16:00', 'Sports Ground',
          'Athletics, cricket, football and badminton events with teams from nearby colleges.'],
      ['Cultural Night', 30, '18:00', '21:30', 'Open Air Theatre',
          'Music, dance and drama performances by students.'],
      ['Blood Donation Camp', -6, '09:00', '14:00', 'Health Centre',
          'Voluntary blood donation camp organised with the local hospital.'],
      ['Alumni Meet', -20, '16:00', '19:00', 'Conference Hall',
          'Annual meeting with alumni to share career experiences and mentor current students.'],
    ];
    for (final e in eventDefs) {
      await db.insert('events', {
        'title': e[0],
        'date': d(today.add(Duration(days: e[1] as int))),
        'start_time': e[2],
        'end_time': e[3],
        'location': e[4],
        'description': e[5],
      });
    }

    // ---- Student notifications ----
    for (final uid in studentUserIds) {
      if (uid == null) continue;
      final items = [
        ['notice', 'New notice: Mid-semester exam timetable released',
            'Open Notices to view the full schedule.', 30, 0],
        ['event', 'Upcoming event: Guest Lecture: AI in Industry',
            'Seminar Hall A, 11:00 AM.', 180, 0],
        ['notice', 'New notice: Library timings extended during exams',
            'The library is open 8:00 AM to 9:00 PM.', 2800, 1],
      ];
      for (final n in items) {
        await db.insert('notifications', {
          'user_id': uid,
          'type': n[0],
          'title': n[1],
          'message': n[2],
          'created_at': iso(now.subtract(Duration(minutes: n[3] as int))),
          'is_read': n[4],
        });
      }
    }

    // ---- Requests ----
    final reqs = [
      [1, 'Bonafide certificate', 'Needed for a scholarship application.', 'Pending'],
      [4, 'ID card replacement', 'Lost my ID card last week.', 'Pending'],
      [12, 'Leave application', 'Medical leave for three days.', 'Pending'],
      [6, 'Fee concession', 'Requesting installment support.', 'Approved'],
    ];
    for (var i = 0; i < reqs.length; i++) {
      final r = reqs[i];
      await db.insert('requests', {
        'student_id': studentPks[r[0] as int],
        'type': r[1],
        'details': r[2],
        'status': r[3],
        'created_at': iso(now.subtract(Duration(hours: 5 + i * 20))),
      });
    }

    // ---- Recent activity ----
    final acts = [
      ['Notice published: Mid-semester exam timetable released', 120],
      ['Attendance updated for CS301, B.Tech CSE Sem 3', 380],
      ['Fee payment recorded, receipt R-1010', 760],
      ['Event created: Annual Tech Fest', 1500],
      ['New student added: Simran Kaur', 2900],
    ];
    for (final a in acts) {
      await db.insert('activity_log', {
        'message': a[0],
        'created_at': iso(now.subtract(Duration(minutes: a[1] as int))),
      });
    }

    await db.insert('app_settings', {'name': 'theme_mode', 'value': 'system'});
  }
}
