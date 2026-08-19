import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Real Web Push + browser notification support (Chrome/Edge/Firefox).
///
/// - [requestWebPermission]: asks for the browser notification permission.
/// - [subscribeToWebPush]: subscribes the VAPID public key via the registered
///   service worker and returns the subscription JSON ready to store
///   server-side (the server then pushes when the tab is fully closed).
/// - [showWebNotification]: raises a browser notification while the tab is
///   open; closed tabs are served by push-sw.js instead.
/// - [listenForWorkerMessages]: forwards "notification tapped" signals from
///   the service worker so the app can open the matching conversation.
Future<bool> requestWebPermission() async {
  if (!kIsWeb) return false;
  if (html.Notification.permission == 'granted') return true;
  if (html.Notification.permission == 'denied') return false;

  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}

Future<String?> subscribeToWebPush(String vapidPublicKey) async {
  if (!kIsWeb) return null;
  try {
    final reg = await html.window.navigator.serviceWorker?.ready;
    final manager = reg?.pushManager;
    if (manager == null) return null;

    // subscribe() resolves to the existing subscription when one is already
    // active, so it covers both first-time and repeat visits.
    final subscription = await manager.subscribe(<String, Object?>{
      'userVisibleOnly': true,
      'applicationServerKey': _base64UrlDecode(vapidPublicKey),
    });

    return jsonEncode({
      'endpoint': subscription.endpoint,
      'keys': {
        'p256dh': subscription.getKey('p256dh'),
        'auth': subscription.getKey('auth'),
      },
    });
  } catch (e) {
    debugPrint('subscribeToWebPush error: $e');
    return null;
  }
}

bool get notificationsSupported => kIsWeb;

bool get canShowWebNotification =>
    kIsWeb &&
    html.Notification.permission == 'granted' &&
    html.document.hidden == false;

void showWebNotification({
  required String title,
  required String body,
  required String tag,
  String? conversationId,
}) {
  if (!canShowWebNotification) return;
  try {
    html.Notification(title, body: body, tag: tag);
  } catch (e) {
    debugPrint('showWebNotification error: $e');
  }
}

void listenForWorkerMessages(
  void Function(String conversationId) onOpenChat,
) {
  if (!kIsWeb) return;
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return;
  sw.addEventListener('message', (event) {
    if (event is html.MessageEvent) {
      final data = event.data;
      if (data is Map) {
        if (data['type'] == 'OPEN_CHAT') {
          onOpenChat(data['conversationId']?.toString() ?? '');
        }
      }
    }
  });
}

Uint8List _base64UrlDecode(String input) {
  final normalized = input.replaceAll('-', '+').replaceAll('_', '/');
  final padded = normalized.padRight(normalized.length + ((4 - normalized.length % 4) % 4), '=');
  return base64.decode(padded);
}