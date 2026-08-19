/// Stub implementations for non-web platforms (Android/iOS/desktop).
///
/// Browser notification APIs (`dart:html`) only exist on the web. This file
/// mirrors [notification_web.dart]'s public surface with safe no-ops so the
/// mobile/client build compiles; native push arrives via FCM instead.
Future<bool> requestWebPermission() async => false;

Future<String?> subscribeToWebPush(String vapidPublicKey) async => null;

bool get notificationsSupported => false;

bool get canShowWebNotification => false;

void showWebNotification({
  required String title,
  required String body,
  required String tag,
  String? conversationId,
}) {}

void listenForWorkerMessages(
  void Function(String conversationId) onOpenChat,
) {}