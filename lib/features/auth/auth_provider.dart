import 'package:smart_campus/core/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_campus/data/models/models.dart';
import 'package:smart_campus/domain/campus_repository.dart';

/// Holds the signed in user. "Remember me" keeps the session between launches.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo);
  final CampusRepository _repo;

  static const _kUid = 'session_user_id';
  static const _kLast = 'last_login_id';

  AppUser? user;
  Student? student;

  bool get isAdmin => user?.role == 'admin';

  Future<AppUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUid);
    if (id == null) return null;
    final u = await _repo.getUser(id);
    if (u == null) {
      await prefs.remove(_kUid);
      return null;
    }
    await _setUser(u);
    return u;
  }

  Future<String?> lastLoginId() async =>
      (await SharedPreferences.getInstance()).getString(_kLast);

  /// Returns an error message, or null when login succeeded.
  Future<String?> login({
    required String loginId,
    required String password,
    required String role,
    required bool remember,
  }) async {
    final u = await _repo.findUser(loginId.trim());
    if (u == null) {
      return 'Account not found. Check your ${role == 'admin' ? 'email' : 'Student ID or email'}, or create an account.';
    }
    if (u.role != role) {
      return 'This is a ${u.role} account. Please select the ${u.role} role.';
    }
    if (!await _repo.verifyPassword(u, password)) {
      return 'Incorrect password. Please try again.';
    }
    await _setUser(u);
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setInt(_kUid, u.id);
      await prefs.setString(_kLast, loginId.trim());
    } else {
      await prefs.remove(_kUid);
      await prefs.remove(_kLast);
    }
    return null;
  }

  Future<void> _setUser(AppUser u) async {
    user = u;
    student = u.role == 'student' ? await _repo.studentByUserId(u.id) : null;
    notifyListeners();
  }

  /// Reloads the signed in user and student record after profile edits.
  Future<void> reload() async {
    final id = user?.id;
    if (id == null) return;
    final u = await _repo.getUser(id);
    if (u != null) await _setUser(u);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUid);
    await NotificationService.instance.cancelAll();
    user = null;
    student = null;
    notifyListeners();
  }
}

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repo);
  final CampusRepository _repo;

  ThemeMode themeMode = ThemeMode.system;

  Future<void> load() async {
    final v = await _repo.getSetting('theme_mode');
    themeMode = _parse(v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _repo.setSetting('theme_mode', mode.name);
  }

  ThemeMode _parse(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
