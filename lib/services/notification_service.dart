import 'dart:io';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;
import 'package:web/web.dart' as web;
import '../models/message.dart';
import '../models/chat.dart';
import '../screens/chat_screen.dart';
import 'api_service.dart';
import 'call_listener.dart';
import 'session.dart';
import 'socket_service.dart';

/// Foreground / basic background notifications.
///
/// Displays a local notification for new messages. On iOS/Android the plugin
/// also supports background delivery as long as the app has been launched at
/// least once and the plugin is initialized; fully terminated-state delivery
/// requires FCM, which is intentionally left out to keep the existing
/// architecture untouched.
///
/// On Flutter Web (Chrome) the plugin has no web implementation, so this
/// service routes through the browser [web.Notification] API instead: a
/// notification is raised while the tab is open but hidden/minimized. Because
/// a completely closed tab has no running Dart isolate (and no Web Push /
/// VAPID infrastructure in this project), closed-browser delivery is NOT
/// claimed.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const _channelId = 'chatt_messages';
  static const _channelName = 'Chat Messages';

  static Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      await requestWebPermission();
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final conversationId = response.payload;
        if (conversationId != null && conversationId.isNotEmpty) {
          openConversation(conversationId);
        }
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Android 13+ (API 33) requires runtime notification permission.
      await android?.requestNotificationsPermission();

      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
      ));
    }

    _initialized = true;
  }

  // ===== Web (Chrome) browser notifications =====

  /// True when the browser exposes the `Notification` API.
  static bool _notificationSupported() => globalContext.has('Notification');

  /// Request the browser Notification permission. On Chrome this prompt is
  /// best triggered by a user gesture, but requesting at startup is the
  /// reliable path once granted.
  static Future<bool> requestWebPermission() async {
    if (!_notificationSupported()) return false;

    var permission = web.Notification.permission;
    if (permission == 'granted') return true;
    if (permission == 'denied') return false;

    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  }

  static void _showWebNotification({
    required String title,
    required String body,
    required String tag,
    required String conversationId,
  }) {
    if (!_notificationSupported()) return;
    if (web.Notification.permission != 'granted') return;

    final notification = web.Notification(
      title,
      web.NotificationOptions(body: body, tag: tag),
    );

    // Clicking focuses the app (which is still running in the background tab)
    // and opens the correct conversation.
    notification.onclick = ((web.Event event) {
      openConversation(conversationId);
    }).toJS;
  }

  /// Show a new-message notification.
  static Future<void> showMessage({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    if (!_initialized) return;

    if (kIsWeb) {
      _showWebNotification(
        title: title,
        body: body,
        tag: payload ?? 'chatt-$id',
        conversationId: payload ?? '',
      );
      return;
    }

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'New chat messages',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Open the conversation matching [conversationId] (called when a
  /// notification is tapped while the app is running).
  static Future<void> openConversation(String conversationId) async {
    final context = CallListener.navigatorKey.currentContext;
    if (context == null) return;

    try {
      final chats = await ApiService.getConversations();
      final chat = chats
          .where((c) => c.id == conversationId)
          .cast<Chat?>()
          .firstWhere((c) => c != null, orElse: () => null);
      if (chat == null) return;
      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chat: chat),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService.openConversation error: $e');
    }
  }
}

/// Subscribes to new-message events and raises a local notification whenever
/// the app is not in the foreground (background / inactive).
class MessageNotificationListener with WidgetsBindingObserver {
  MessageNotificationListener._();
  static final MessageNotificationListener instance =
      MessageNotificationListener._();

  bool _foreground = true;
  int _counter = 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    SocketService.instance.onNewMessage.listen((event) {
      if (_foreground) return;
      final msg = event.message;
      // Never notify about our own messages.
      if (msg.senderId != null &&
          msg.senderId == Session.userId) {
        return;
      }
      _counter = (_counter % 99) + 1;
      NotificationService.showMessage(
        title: msg.senderName ?? 'New message',
        body: _bodyFor(msg),
        id: _counter,
        payload: event.conversationId,
      );
    });
  }

  String _bodyFor(Message msg) {
    final type = msg.type.name;
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'voice':
        return '🎤 Voice message';
      case 'file':
        return '📎 File';
      case 'video':
        return '🎬 Video';
      case 'videoCall':
        return '📹 Video call';
      case 'voiceCall':
        return '📞 Voice call';
      default:
        return msg.text;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }
}

