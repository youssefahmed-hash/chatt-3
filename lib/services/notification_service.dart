import 'dart:async';
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
import 'notification_web.dart' as notif_web;
import 'session.dart';
import 'socket_service.dart';

/// Foreground + background + closed-tab notifications.
///
/// - Android/iOS (app open or backgrounded): flutter_local_notifications.
/// - Web (tab open): browser [html.Notification].
/// - Web (tab fully closed): Web Push via the registered service worker
///   (push-sw.js) — the server pushes directly to every registered device.
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
      final granted = await requestWebPermission();
      if (granted) {
        unawaited(_initWebPush());
      }
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

  /// Fetch the server VAPID public key, subscribe the service worker and
  /// register the device so the server can push when the tab is closed.
  static Future<void> _initWebPush() async {
    try {
      final config = await ApiService.getPushConfig();
      if (config == null) return;

      final token = await notif_web.subscribeToWebPush(
        config['publicKey']?.toString() ?? '',
      );
      if (token == null || token.isEmpty) return;

      await ApiService.registerDevice(token, 'web');

      notif_web.listenForWorkerMessages((conversationId) {
        if (conversationId.isEmpty) return;
        openConversation(conversationId);
      });
    } catch (e) {
      debugPrint('Web push init error: $e');
    }
  }

  /// Request the browser Notification permission. On Chrome this prompt is
  /// best triggered by a user gesture, but requesting at startup is the
  /// reliable path once granted.
  static Future<bool> requestWebPermission() =>
      notif_web.requestWebPermission();

  static void _showWebNotification({
    required String title,
    required String body,
    required String tag,
    required String conversationId,
  }) {
    if (!notif_web.canShowWebNotification) return;
    notif_web.showWebNotification(
      title: title,
      body: body,
      tag: tag,
      conversationId: conversationId,
    );
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

