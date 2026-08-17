import 'package:flutter/foundation.dart';

/// Browser notifications are intentionally disabled for this mobile-first app.
/// Keeping the file as a pure no-op prevents Android builds from pulling in
/// package:web or dart:js_interop via a stray app-level import.
class notificationWeb {
  static bool supported() => false;

  static Future<bool> requestWebPermission() async => false;

  static void showWebNotification({
    required String title,
    required String body,
    required String tag,
    required String conversationId,
    required Future<void> Function(String) onTap,
  }) {
    if (kDebugMode) {
      // Browser notification path is intentionally off for Android builds.
    }
  }
}
