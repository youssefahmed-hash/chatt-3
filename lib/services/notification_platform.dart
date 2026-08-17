import 'package:flutter/foundation.dart';

class NotificationPlatform {
  static Future<bool> requestWebPermission() async {
    return false;
  }

  static void showWebNotification({
    required String title,
    required String body,
    required String tag,
    required String conversationId,
    required Future<void> Function(String) onTap,
  }) {
    if (kIsWeb) {
      // keep browser notification logic out of Android builds.
    }
  }
}
