import 'package:shared_preferences/shared_preferences.dart';

/// Persists the auth session (JWT + current user id/name/role) across app restarts.
class Session {
  static const _kToken = 'auth_token';
  static const _kUserId = 'user_id';
  static const _kUserName = 'user_name';
  static const _kUserRole = 'user_role';
  static const _kMustChangeCreds = 'must_change_creds';

  static String? token;
  static String? userId;
  static String? userName;
  static String? role;
  static bool mustChangeCredentials = false;

  /// Load any saved session into memory. Call once on app start.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    userId = prefs.getString(_kUserId);
    userName = prefs.getString(_kUserName);
    role = prefs.getString(_kUserRole) ?? 'user';
    mustChangeCredentials = prefs.getBool(_kMustChangeCreds) ?? false;
  }

  static Future<void> save({
    required String token,
    required String userId,
    required String userName,
    required String role,
    required bool mustChangeCredentials,
  }) async {
    Session.token = token;
    Session.userId = userId;
    Session.userName = userName;
    Session.role = role;
    Session.mustChangeCredentials = mustChangeCredentials;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kUserRole, role);
    await prefs.setBool(_kMustChangeCreds, mustChangeCredentials);
  }

  static Future<void> setMustChangeCredentials(bool value) async {
    Session.mustChangeCredentials = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMustChangeCreds, value);
  }

  static Future<void> clear() async {
    token = null;
    userId = null;
    userName = null;
    role = null;
    mustChangeCredentials = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserRole);
    await prefs.remove(_kMustChangeCreds);
  }

  static bool get isLoggedIn => token != null && token!.isNotEmpty;
  static bool get isAdmin => role == 'admin';
}
