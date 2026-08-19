import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;
import '../l10n/generated/app_localizations.dart';
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

  /// Current app language — used to format notification titles/bodies.
  /// Kept up to date from [main.dart] via the [LocaleProvider].
  static Locale locale = const Locale('en');

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

      await android?.createNotificationChannel(AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('chatt_notification'),
        vibrationPattern: Int64List.fromList([0, 250, 120, 250]),
      ));
    }

    _initialized = true;
  }

  // ===== Web (Chrome) browser notifications =====

  /// Request the browser Notification permission. On Chrome this prompt is
  /// best triggered by a user gesture, but requesting at startup is the
  /// reliable path once granted.
  static Future<bool> requestWebPermission() async {
    if (!kIsWeb) return false;
    return false;
  }

  static void _showWebNotification({
    required String title,
    required String body,
    required String tag,
    required String conversationId,
  }) {
    // Web notifications are intentionally disabled for this mobile-first app.
    // Browser support is not required for Android APK builds.
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
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'New chat messages',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('chatt_notification'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 250, 120, 250]),
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
      final l10n = lookupAppLocalizations(NotificationService.locale);
      _counter = (_counter % 99) + 1;
      NotificationService.showMessage(
        title: msg.senderName ?? l10n.newMessageNotificationTitle,
        body: _bodyFor(msg, l10n),
        id: _counter,
        payload: event.conversationId,
      );
    });
  }

  String _bodyFor(Message msg, AppLocalizations l10n) {
    final type = msg.type.name;
    switch (type) {
      case 'image':
        return l10n.photoNotification;
      case 'voice':
        return l10n.voiceNotification;
      case 'file':
        return l10n.fileNotification;
      case 'video':
        return l10n.videoNotification;
      case 'videoCall':
        return l10n.videoCallNotification;
      case 'voiceCall':
        return l10n.voiceCallNotification;
      default:
        return msg.text;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }
}

