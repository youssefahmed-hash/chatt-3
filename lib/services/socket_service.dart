import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import 'session.dart';
/// Wraps the Socket.IO connection to the chatt backend.
///
/// Usage:
///   SocketService.instance.connect();
///   SocketService.instance.onNewMessage.listen((event) { ... });
///   SocketService.instance.sendMessage(conversationId: ..., text: ...);
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;

  // Broadcast streams the UI can subscribe to.
  final _connectionState = StreamController<bool>.broadcast();
  final _newMessage = StreamController<NewMessageEvent>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _presence = StreamController<PresenceEvent>.broadcast();
  final _deletedMessage = StreamController<DeletedMessageEvent>.broadcast();
  final _groupAdded = StreamController<GroupAddedEvent>.broadcast();
  final _groupMembersUpdated = StreamController<GroupMembersUpdatedEvent>.broadcast();
  final _groupAdminsUpdated = StreamController<GroupAdminsUpdatedEvent>.broadcast();
  final _groupUpdatedController = StreamController<GroupUpdatedEvent>.broadcast();
  final _incomingCall = StreamController<IncomingCallEvent>.broadcast();
  final _callAccepted = StreamController<CallAcceptedEvent>.broadcast();
  final _callRejected = StreamController<CallRejectedEvent>.broadcast();
  final _callEnded = StreamController<CallEndedEvent>.broadcast();
  final _messageEdited = StreamController<MessageEditedEvent>.broadcast();
  final _reactionAdded = StreamController<ReactionEvent>.broadcast();
  final _reactionRemoved = StreamController<ReactionEvent>.broadcast();
  final _messagePinned = StreamController<PinnedEvent>.broadcast();
  final _messageUnpinned = StreamController<PinnedEvent>.broadcast();
  final _recordingStarted = StreamController<RecordingEvent>.broadcast();
  final _recordingStopped = StreamController<RecordingEvent>.broadcast();
  final _conversationArchived = StreamController<ArchivedEvent>.broadcast();
  final _readReceipt = StreamController<ReadReceiptEvent>.broadcast();
  Stream<NewMessageEvent> get onNewMessage => _newMessage.stream;
  Stream<TypingEvent> get onTyping => _typing.stream;
  Stream<PresenceEvent> get onPresence => _presence.stream;
  Stream<DeletedMessageEvent> get onDeletedMessage => _deletedMessage.stream;
  Stream<GroupAddedEvent> get onGroupAdded => _groupAdded.stream;
  Stream<GroupMembersUpdatedEvent> get onGroupMembersUpdated => _groupMembersUpdated.stream;
  Stream<GroupAdminsUpdatedEvent> get onGroupAdminsUpdated => _groupAdminsUpdated.stream;
  Stream<GroupUpdatedEvent> get onGroupUpdated => _groupUpdatedController.stream;
  Stream<IncomingCallEvent> get onIncomingCall => _incomingCall.stream;
  Stream<CallAcceptedEvent> get onCallAccepted => _callAccepted.stream;
  Stream<CallRejectedEvent> get onCallRejected => _callRejected.stream;
  Stream<CallEndedEvent> get onCallEnded => _callEnded.stream;
  Stream<MessageEditedEvent> get onMessageEdited => _messageEdited.stream;
  Stream<ReactionEvent> get onReactionAdded => _reactionAdded.stream;
  Stream<ReactionEvent> get onReactionRemoved => _reactionRemoved.stream;
  Stream<PinnedEvent> get onMessagePinned => _messagePinned.stream;
  Stream<PinnedEvent> get onMessageUnpinned => _messageUnpinned.stream;
  Stream<RecordingEvent> get onRecordingStarted => _recordingStarted.stream;
  Stream<RecordingEvent> get onRecordingStopped => _recordingStopped.stream;
  Stream<ArchivedEvent> get onConversationArchived => _conversationArchived.stream;
  Stream<ReadReceiptEvent> get onMessageRead => _readReceipt.stream;
  Stream<bool> get connectionState => _connectionState.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null) return; // already initialised
    if (!Session.isLoggedIn) return;

    _socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': Session.token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _log('connected');
        if (!_connectionState.isClosed) _connectionState.add(true);
      })
      ..onDisconnect((_) {
        _log('disconnected');
        if (!_connectionState.isClosed) _connectionState.add(false);
      })
      ..onConnectError((e) => _log('connect_error: $e'))
      ..on('message:new', (data) {
        final message = _tryParseMessage(data?['message']);
        if (message == null) return;
        _newMessage.add(NewMessageEvent(
          conversationId: data['conversationId']?.toString() ?? '',
          message: message,
        ));
      })
      ..on('typing', (data) {
        _typing.add(TypingEvent(
          conversationId: data['conversationId']?.toString() ?? '',
          userId: data['userId']?.toString() ?? '',
          typing: data['typing'] == true,
        ));
      })
      ..on('presence:update', (data) {
      _presence.add(PresenceEvent(
      userId: data['userId']?.toString() ?? '',
      online: data['online'] == true,
      ));
      })

      ..on('message:deleted', (data) {
      _deletedMessage.add(
      DeletedMessageEvent(
      conversationId: data['conversationId']?.toString() ?? '',
      messageId: data['messageId']?.toString() ?? '',
      ),
      );



      })

      ..on('group:added', (data) {
      _groupAdded.add(
      GroupAddedEvent(
      data['conversation'] as Map<String, dynamic>,
      ),
      );
      })


      ..on('group:membersUpdated', (data) {
        _groupMembersUpdated.add(
          GroupMembersUpdatedEvent(
            conversationId: data['conversationId'].toString(),
            members: (data['members'] as List)
                .cast<Map<String, dynamic>>(),
          ),
        );
      })

      ..on('group:adminsUpdated', (data) {

        _groupAdminsUpdated.add(

          GroupAdminsUpdatedEvent(

            conversationId:
            data['conversationId'].toString(),

            admins:
            (data['admins'] as List)
                .map((e)=>e.toString())
                .toList(),

          ),

        );

      })

      ..on('group:updated', (data) {
        _groupUpdatedController.add(
          GroupUpdatedEvent(
            conversationId: data['conversationId'].toString(),
            groupName: data['groupName'].toString(),
            groupImage: data['groupImage']?.toString(),
          ),
        );
      })
    ..on('incoming:call', (data) {
    _incomingCall.add(
    IncomingCallEvent(
    conversationId: data['conversationId'].toString(),
    roomName: data['roomName'].toString(),
    type: data['type'].toString(),
    caller: Map<String, dynamic>.from(data['caller']),
    ),
    );
    })

    ..on('call:accepted', (data) {
      print("SOCKET call:accepted");
      print(data);
    _callAccepted.add(
    CallAcceptedEvent(
    roomName: data['roomName'].toString(),
    ),
    );
    })

    ..on('call:rejected', (_) {
    _callRejected.add(CallRejectedEvent());
    })

    ..on('call:ended', (_) {
    _callEnded.add(CallEndedEvent());
    })

    ..on('message:edited', (data) {
      final message = _tryParseMessage(data?['message']);
      if (message == null) return;
      _messageEdited.add(MessageEditedEvent(
        conversationId: data['conversationId']?.toString() ?? '',
        message: message,
      ));
    })

    ..on('reaction:added', (data) {
      _reactionAdded.add(_reactionFromData(data));
    })

    ..on('reaction:removed', (data) {
      _reactionRemoved.add(_reactionFromData(data));
    })

    ..on('message:pinned', (data) {
      _messagePinned.add(PinnedEvent(
        conversationId: data['conversationId']?.toString() ?? '',
        messageId: data['messageId']?.toString() ?? '',
        pinnedMessageIds: (data['pinnedMessageIds'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      ));
    })

    ..on('message:unpinned', (data) {
      _messageUnpinned.add(PinnedEvent(
        conversationId: data['conversationId']?.toString() ?? '',
        messageId: data['messageId']?.toString() ?? '',
        pinnedMessageIds: (data['pinnedMessageIds'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      ));
    })

    ..on('recording:started', (data) {
      _recordingStarted.add(RecordingEvent(
        conversationId: data['conversationId']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
      ));
    })

    ..on('recording:stopped', (data) {
      _recordingStopped.add(RecordingEvent(
        conversationId: data['conversationId']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
      ));
    })

    ..on('message:read', (data) {
      final rawMessages = data?['messages'] as List? ?? const [];
      final messages = rawMessages
          .map(_tryParseMessage)
          .whereType<Message>()
          .toList();
      if (messages.isEmpty) return;
      _readReceipt.add(ReadReceiptEvent(
        conversationId: data?['conversationId']?.toString() ?? '',
        readerId: data?['readerId']?.toString() ?? '',
        messages: messages,
      ));
    })

    ..on('conversation:archived', (data) {
      _conversationArchived.add(ArchivedEvent(
        conversationId: data['conversationId']?.toString() ?? '',
        archived: data['archived'] == true,
      ));
    });

    _socket!.connect();
  }

  ReactionEvent _reactionFromData(Map<dynamic, dynamic> data) {
    final rawReactions = data['reactions'] as Map<dynamic, dynamic>? ?? {};
    final reactions = <String, ReactionSummary>{};
    rawReactions.forEach((emoji, value) {
      final v = value as Map<dynamic, dynamic>;
      reactions[emoji.toString()] = ReactionSummary(
        count: (v['count'] as num?)?.toInt() ?? 0,
        userIds: (v['userIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
    });
    return ReactionEvent(
      conversationId: data['conversationId']?.toString() ?? '',
      messageId: data['messageId']?.toString() ?? '',
      emoji: data['emoji']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      reactions: reactions,
    );
  }

  /// Parse a message payload defensively: a single malformed message (e.g. a
  /// server value of an unexpected type) must never throw out of a socket
  /// callback, which would break every subsequent event for the chat.
  Message? _tryParseMessage(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return Message.fromJson(raw.cast<String, dynamic>(), Session.userId ?? '');
    } catch (e) {
      _log('skipping unparseable message payload: $e');
      return null;
    }
  }

  /// Send a message. The server persists it and echoes it back via
  /// `message:new` (including to the sender), so the UI updates from the
  /// single onNewMessage stream.
  void sendMessage({
    required String conversationId,
    String text = '',
    MessageType type = MessageType.text,
    String? callUrl,
    String? replyToId,
    String? forwardedFrom,
    String? clientId,
    void Function(bool ok, String? error)? onResult,
  }) {
    final payload = {
      'conversationId': conversationId,
      'text': text,
      'type': type.asString,
      'callUrl': ?callUrl,
      'replyToId': ?replyToId,
      'forwardedFrom': ?forwardedFrom,
      'clientId': ?clientId,
    };
    if (onResult != null) {
      _socket?.emitWithAck('message:send', payload, ack: (data) {
        final ok = data != null && data['ok'] == true;
        onResult(ok, data?['error']?.toString());
      });
    } else {
      _socket?.emit('message:send', payload);
    }
  }

  /// Edit an existing text message (own messages only).
  void editMessage({
    required String conversationId,
    required String messageId,
    required String text,
    void Function(bool ok, String? error)? onResult,
  }) {
    final payload = {
      'conversationId': conversationId,
      'messageId': messageId,
      'text': text,
    };    if (onResult != null) {
      _socket?.emitWithAck('message:edit', payload, ack: (data) {
        final ok = data != null && data['ok'] == true;
        onResult(ok, data?['error']?.toString());
      });
    } else {
      _socket?.emit('message:edit', payload);
    }
  }

  /// Add (or toggle-keep) an emoji reaction.
  void addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    _socket?.emit('reaction:add', {
      'conversationId': conversationId,
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  void removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    _socket?.emit('reaction:remove', {
      'conversationId': conversationId,
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  /// Tell the conversation that this user started / stopped recording.
  void setRecording({required String conversationId, required bool recording}) {
    _socket?.emit(
      recording ? 'recording:started' : 'recording:stopped',
      {'conversationId': conversationId},
    );
  }

  void setTyping({
    required String conversationId,
    required String peerId,
    required bool typing,
  }) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'peerId': peerId,
      'typing': typing,
    });
  }

  void markRead({required String conversationId, required String peerId}) {
    _socket?.emit('message:read', {
      'conversationId': conversationId,
      'peerId': peerId,
    });
  }
  void startCall({
    required String conversationId,
    required String roomName,
    required MessageType type,
  }) {
    _socket?.emit(
      'call:start',
      {
        'conversationId': conversationId,
        'roomName': roomName,
        'type': type.asString,
      },
    );
  }

  void acceptCall({
    required String callerId,
    required String roomName,
    required String conversationId,
    required String type,
  }) {
    _socket?.emit(
      'call:accept',
      {
        'callerId': callerId,
        'roomName': roomName,
        'conversationId': conversationId,
        'type': type,
      },
    );
  }

  void rejectCall({
    required String callerId,
    required String conversationId,
  }) {
    _socket?.emit(
      'call:reject',
      {
        'callerId': callerId,
        'conversationId': conversationId,
      },
    );
  }

  void endCall({
    required String conversationId,
  }) {
    _socket?.emit(
      'call:end',
      {
        'conversationId': conversationId,
      },
    );
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[socket] $msg');
  }
}

class NewMessageEvent {
  final String conversationId;
  final Message message;
  NewMessageEvent({required this.conversationId, required this.message});
}

class TypingEvent {
  final String conversationId;
  final String userId;
  final bool typing;
  TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.typing,
  });
}

class PresenceEvent {
  final String userId;
  final bool online;
  PresenceEvent({required this.userId, required this.online});
}

class DeletedMessageEvent {
  final String conversationId;
  final String messageId;

  DeletedMessageEvent({
    required this.conversationId,
    required this.messageId,
  });
}

class GroupAddedEvent {
  final Map<String, dynamic> conversation;

  GroupAddedEvent(this.conversation);
}

class GroupMembersUpdatedEvent {
  final String conversationId;
  final List<Map<String, dynamic>> members;

  GroupMembersUpdatedEvent({
    required this.conversationId,
    required this.members,
  });
}

class GroupUpdatedEvent {
  final String conversationId;
  final String groupName;
  final String? groupImage;

  GroupUpdatedEvent({
    required this.conversationId,
    required this.groupName,
    this.groupImage,
  });
}

class GroupAdminsUpdatedEvent {

  final String conversationId;

  final List<String> admins;

  GroupAdminsUpdatedEvent({

    required this.conversationId,

    required this.admins,

  });


}
class IncomingCallEvent {
  final String conversationId;
  final String roomName;
  final String type;
  final Map<String, dynamic> caller;

  IncomingCallEvent({
    required this.conversationId,
    required this.roomName,
    required this.type,
    required this.caller,
  });
}

class CallAcceptedEvent {
  final String roomName;

  CallAcceptedEvent({
    required this.roomName,
  });
}

class CallRejectedEvent {}

class CallEndedEvent {}

class MessageEditedEvent {
  final String conversationId;
  final Message message;

  MessageEditedEvent({required this.conversationId, required this.message});
}

class ReactionEvent {
  final String conversationId;
  final String messageId;
  final String emoji;
  final String userId;
  final Map<String, ReactionSummary> reactions;

  ReactionEvent({
    required this.conversationId,
    required this.messageId,
    required this.emoji,
    required this.userId,
    required this.reactions,
  });
}

class PinnedEvent {
  final String conversationId;
  final String messageId;
  final List<String> pinnedMessageIds;

  PinnedEvent({
    required this.conversationId,
    required this.messageId,
    required this.pinnedMessageIds,
  });
}

class RecordingEvent {
  final String conversationId;
  final String userId;

  RecordingEvent({required this.conversationId, required this.userId});
}

class ArchivedEvent {
  final String conversationId;
  final bool archived;

  ArchivedEvent({required this.conversationId, required this.archived});
}

class ReadReceiptEvent {
  final String conversationId;
  final String readerId;
  final List<Message> messages;

  ReadReceiptEvent({
    required this.conversationId,
    required this.readerId,
    required this.messages,
  });
}
