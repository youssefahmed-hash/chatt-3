import 'package:shared_preferences/shared_preferences.dart';

/// Persists the auth session (JWT + current user id/name) across app restarts.
class Session {
  static const _kToken = 'auth_token';
  static const _kUserId = 'user_id';
  static const _kUserName = 'user_name';

  static String? token;
  static String? userId;
  static String? userName;

  /// Load any saved session into memory. Call once on app start.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    userId = prefs.getString(_kUserId);
    userName = prefs.getString(_kUserName);
  }

  static Future<void> save({
    required String token,
    required String userId,
    required String userName,
  }) async {
    Session.token = token;
    Session.userId = userId;
    Session.userName = userName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserName, userName);
  }

  static Future<void> clear() async {
    token = null;
    userId = null;
    userName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
  }

  static bool get isLoggedIn => token != null && token!.isNotEmpty;
}
