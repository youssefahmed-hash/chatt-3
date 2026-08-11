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
      ..onConnect((_) => _log('connected'))
      ..onDisconnect((_) => _log('disconnected'))
      ..onConnectError((e) => _log('connect_error: $e'))
      ..on('message:new', (data) {
        final myId = Session.userId ?? '';
        _newMessage.add(NewMessageEvent(
          conversationId: data['conversationId']?.toString() ?? '',
          message: Message.fromJson(
              (data['message'] as Map).cast<String, dynamic>(), myId),
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
    });

    _socket!.connect();
  }

  /// Send a message. The server persists it and echoes it back via
  /// `message:new` (including to the sender), so the UI updates from the
  /// single onNewMessage stream.
  void sendMessage({
    required String conversationId,
    String text = '',
    MessageType type = MessageType.text,
    String? callUrl,
  }) {
    _socket?.emit('message:send', {
      'conversationId': conversationId,
      'text': text,
      'type': type.asString,
      if (callUrl != null) 'callUrl': callUrl,
    });
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
  }) {
    _socket?.emit(
      'call:accept',
      {
        'callerId': callerId,
        'roomName': roomName,
      },
    );
  }

  void rejectCall({
    required String callerId,
  }) {
    _socket?.emit(
      'call:reject',
      {
        'callerId': callerId,
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
