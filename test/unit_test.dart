import 'package:flutter_test/flutter_test.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/core/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('student@college.edu'), isNull);
    });

    test('phone must be 10 digits', () {
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('98765abcde'), isNotNull);
      expect(Validators.phone('9876543210'), isNull);
    });

    test('password length', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('login id accepts email or student id', () {
      expect(Validators.loginId(''), isNotNull);
      expect(Validators.loginId('CS2301'), isNull);
      expect(Validators.loginId('admin@smartcampus.com'), isNull);
      expect(Validators.loginId('bad@'), isNotNull);
    });

    test('confirm password', () {
      final check = Validators.confirm(() => 'secret1');
      expect(check('secret1'), isNull);
      expect(check('other'), isNotNull);
    });
  });

  group('Attendance percentage', () {
    test('zero total gives zero', () => expect(attendancePercent(0, 0), 0));
    test('three of four is 75', () => expect(attendancePercent(3, 4), 75));
    test('all present is 100', () => expect(attendancePercent(20, 20), 100));
  });

  group('Timetable clash logic', () {
    test('overlapping slots clash', () {
      expect(timesOverlap('09:00', '10:00', '09:30', '10:30'), isTrue);
      expect(timesOverlap('09:00', '11:00', '10:00', '10:30'), isTrue);
    });

    test('back to back slots do not clash', () {
      expect(timesOverlap('09:00', '10:00', '10:00', '11:00'), isFalse);
      expect(timesOverlap('13:00', '14:00', '09:00', '10:00'), isFalse);
    });
  });

  group('Helpers', () {
    test('time12', () {
      expect(Fmt.time12('00:30'), '12:30 AM');
      expect(Fmt.time12('09:05'), '9:05 AM');
      expect(Fmt.time12('13:00'), '1:00 PM');
    });

    test('initials', () {
      expect(initials('Aarav Mehta'), 'AM');
      expect(initials('Madonna'), 'M');
    });

    test('password hashing is salted and repeatable', () {
      final salt = PasswordHasher.newSalt();
      final a = PasswordHasher.hash('Admin@123', salt);
      expect(PasswordHasher.hash('Admin@123', salt), a);
      expect(PasswordHasher.hash('Admin@123', PasswordHasher.newSalt()), isNot(a));
      expect(PasswordHasher.hash('wrong', salt), isNot(a));
    });
  });
}
