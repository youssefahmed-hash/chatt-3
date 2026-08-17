import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';
import 'socket_service.dart';

/// A text message queued locally while the user is offline.
class PendingMessage {
  final String id;
  final String conversationId;
  final String text;
  final DateTime createdAt;
  final String? replyToId;
  /// User whose identity owns this queued message. A message must never be
  /// delivered under a different account on the same device.
  final String? userId;

  const PendingMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.createdAt,
    this.replyToId,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'replyToId': ?replyToId,
        'userId': userId,
      };

  factory PendingMessage.fromJson(Map<String, dynamic> json) =>
      PendingMessage(
        id: json['id'],
        conversationId: json['conversationId'],
        text: json['text'],
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        replyToId: json['replyToId']?.toString(),
        userId: json['userId']?.toString(),
      );
}

/// Persistent offline message queue.
///
/// Text messages that cannot be delivered (socket disconnected / server
/// error) are stored in [SharedPreferences] and automatically retried once
/// the socket reconnects. Messages are kept in FIFO order and each carries a
/// unique local id so a message is never sent twice.
class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _key = 'offline_queue';

  final List<PendingMessage> _queue = [];
  StreamSubscription? _connectSub;
  bool _flushing = false;

  List<PendingMessage> get pending => List.unmodifiable(_queue);

  /// Load persisted messages and start auto-flush on reconnect.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _queue.clear();
        _queue.addAll(
          list.map((e) => PendingMessage.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {}
    }

    _connectSub?.cancel();
    _connectSub = SocketService.instance.connectionState.listen((connected) {
      if (connected) {
        flush();
      }
    });
  }

  Stream<bool> get connectionState =>
      SocketService.instance.connectionState;

  /// Add a message to the tail of the queue (persisted).
  Future<void> enqueue(PendingMessage message) async {
    // Stamp ownership as the identity active right now, so a message recorded
    // for one account can never be flushed as another later.
    final owned = message.userId == null || message.userId!.isEmpty
        ? PendingMessage(
            id: message.id,
            conversationId: message.conversationId,
            text: message.text,
            createdAt: message.createdAt,
            replyToId: message.replyToId,
            userId: Session.userId,
          )
        : message;
    _queue.add(owned);
    await _persist();
  }

  /// Remove every queued message (e.g. on logout) so a pending message from a
  /// signed-out identity is never delivered after the next login.
  Future<void> clear() async {
    _queue.clear();
    await _persist();
  }

  /// Remove a message (delivered / cancelled).
  Future<void> remove(String id) async {
    _queue.removeWhere((m) => m.id == id);
    await _persist();
  }

  /// Try to deliver every queued message in order.
  Future<void> flush() async {
    if (_flushing) return;
    if (!SocketService.instance.isConnected) return;

    _flushing = true;
    try {
      // Snapshot so removals don't disturb iteration.
      final snapshot = List<PendingMessage>.from(_queue);
      for (final msg in snapshot) {
        final owner = Session.userId;
        // Never deliver a queued message under a different identity than the
        // one that created it (e.g. after an account switch on this device).
        if (owner == null || msg.userId != owner) {
          await remove(msg.id);
          continue;
        }
        await _sendOne(msg);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _sendOne(PendingMessage msg) async {
    if (!SocketService.instance.isConnected) return;

    final completer = Completer<bool>();

    SocketService.instance.sendMessage(
      conversationId: msg.conversationId,
      text: msg.text,
      replyToId: msg.replyToId,
      clientId: msg.id,
      onResult: (ok, _) {
        if (!completer.isCompleted) completer.complete(ok);
      },
    );

    try {
      final ok = await completer.future.timeout(const Duration(seconds: 10));
      if (ok) {
        await remove(msg.id);
      }
    } catch (_) {
      // Timeout — leave in queue, retry on next flush.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_queue.map((m) => m.toJson()).toList()),
    );
  }
}
