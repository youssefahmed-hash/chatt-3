import 'package:flutter/foundation.dart';

/// Central place for the backend base URL.
///
/// - Android emulator reaches the host machine at 10.0.2.2 (not localhost).
/// - iOS simulator / desktop / web can use localhost.
/// - For a real phone, set [overrideHost] to your PC's LAN IP (e.g. 192.168.1.5)
///   and make sure the phone is on the same Wi-Fi.
///
/// Uses [defaultTargetPlatform] (not dart:io) so it also compiles on web.
class ApiConfig {
  /// Set this to your PC's LAN IP to test on a physical device, e.g. '192.168.1.5'.
  static const String? overrideHost = null;

  static const int port = 4000;

  static String get _host {
    if (overrideHost != null) return overrideHost!;
    if (kIsWeb) return 'localhost';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  /// e.g. http://10.0.2.2:4000
  static String get baseUrl => 'http://$_host:$port';

  /// REST API root, e.g. http://10.0.2.2:4000/api
  static String get apiUrl => '$baseUrl/api';
}
