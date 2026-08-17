import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central place for the backend base URL.
/// Supports dynamically loading and storing configured domain/URL (e.g. from Cloudflare Tunnel).
class ApiConfig {
  static const String? overrideHost = null;
  static const int port = 4000;

  static String? _dynamicBaseUrl;

  /// Load custom API URL from SharedPreferences
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dynamicBaseUrl = prefs.getString('dynamic_api_base_url');
    } catch (_) {}
  }

  /// Store and update dynamic API URL
  static Future<void> setBaseUrl(String? url) async {
    _dynamicBaseUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null || url.trim().isEmpty) {
        await prefs.remove('dynamic_api_base_url');
      } else {
        String formattedUrl = url.trim();
        if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
          formattedUrl = 'https://$formattedUrl';
        }
        await prefs.setString('dynamic_api_base_url', formattedUrl);
      }
    } catch (_) {}
  }

  static String get _host {
    if (overrideHost != null) return overrideHost!;
    if (kIsWeb) return 'localhost';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  /// Returns the configured dynamic URL, or the default developer fallback
  static String get baseUrl {
    if (_dynamicBaseUrl != null && _dynamicBaseUrl!.isNotEmpty) {
      return _dynamicBaseUrl!;
    }
    return 'http://$_host:$port';
  }

  /// REST API root
  static String get apiUrl => '$baseUrl/api';
}
