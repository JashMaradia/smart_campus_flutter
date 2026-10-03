import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1E40AF);
  static const teal = Color(0xFF0F766E);
  static const amber = Color(0xFFB45309);
  static const danger = Color(0xFFB91C1C);
  static const success = Color(0xFF15803D);
  static const violet = Color(0xFF6D28D9);
}

class AppStrings {
  static const appName = 'Smart Campus';
  static const tagline = 'One Campus, One Smart Solution';
  static const collegeName = 'Smart Campus College';
  static const adminEmail = 'admin@smartcampus.com';
  static const adminPassword = 'Admin@123';
  static const demoStudentId = 'CS2301';
  static const defaultStudentPassword = 'Student@123';
  static const minAttendance = 75;
}

/// Program name -> department.
const Map<String, String> kPrograms = {
  'B.Tech CSE': 'Computer Science',
  'B.Tech ECE': 'Electronics',
  'B.Tech Mechanical': 'Mechanical',
};

const List<int> kSemesters = [1, 2, 3, 4, 5, 6, 7, 8];
const List<String> kNoticeCategories = ['General', 'Exam', 'Event', 'Urgent'];
const List<String> kPaymentMethods = ['UPI', 'Cash', 'Card', 'Bank transfer'];
const List<String> kRequestTypes = [
  'Bonafide certificate',
  'ID card replacement',
  'Leave application',
  'Fee concession',
];
const List<String> kDayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

String dayName(int dayOfWeek) =>
    (dayOfWeek >= 1 && dayOfWeek <= 6) ? kDayNames[dayOfWeek - 1] : 'Sunday';

Color categoryColor(String category) {
  switch (category) {
    case 'Exam':
      return AppColors.amber;
    case 'Event':
      return AppColors.teal;
    case 'Urgent':
      return AppColors.danger;
    default:
      return AppColors.primary;
  }
}
