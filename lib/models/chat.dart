import 'message.dart';
import 'group_member.dart';

class Chat {
  final String? id;

  final String? peerId;

  final bool isGroup;

  String? groupImage;

  final List<String> admins;

  final String? createdBy;

  List<GroupMember> members;

  String name;

  String lastMessage;

  String? lastMessageSender;

  String time;

  final List<Message> messages;

  final List<String> pinnedMessageIds;

  bool peerOnline;

  String? peerLastSeen;

  int unreadCount;

  bool pinned;

  Chat({
    this.id,
    this.peerId,
    this.isGroup = false,
    this.groupImage,
    this.members = const [],
    this.admins = const [],
    this.createdBy,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.messages,
    this.pinnedMessageIds = const [],
    this.peerOnline = false,
    this.peerLastSeen,
    this.unreadCount = 0,
    this.lastMessageSender,
    this.pinned = false,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;

    final isGroup = json['isGroup'] == true;

    if (isGroup) {
      final membersList = (json['members'] as List?)
          ?.map((e) => GroupMember.fromJson(
        e as Map<String, dynamic>,
      ))
          .toList() ??
          [];

      final rawSender = last?['sender']?.toString();
      var senderName = last?['senderName']?.toString();
      if ((senderName == null || senderName.isEmpty) &&
          rawSender != null) {
        // Old servers only send the sender id; resolve the name from the
        // member list included in the same payload.
        for (final m in membersList) {
          if (m.id == rawSender) {
            senderName = m.name;
            break;
          }
        }
      }

      return Chat(
        id: json['id']?.toString(),
        peerId: null,
        isGroup: true,
        groupImage: json['groupImage'],
        members: membersList,
        admins: (json['admins'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        createdBy: json['createdBy']?.toString(),
        name: json['groupName'] ?? '',
        lastMessage: last?['text'] ?? '',
        lastMessageSender: senderName ?? rawSender,
        time: _formatTime(last?['at'] ?? json['updatedAt']),
        messages: [],
        pinnedMessageIds: (json['pinnedMessageIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        pinned: json['pinned'] == true,
      );
    }

    final peer = json['peer'] as Map<String, dynamic>?;

    return Chat(
      id: json['id']?.toString(),
      peerId: peer?['id']?.toString(),
      isGroup: false,
      groupImage: null,
      members: const [],
      name: peer?['name'] ?? '',
      lastMessage: last?['text'] ?? '',
      lastMessageSender: last?['senderName']?.toString() ??
          last?['sender']?.toString(),
      time: _formatTime(last?['at'] ?? json['updatedAt']),
      messages: [],
      admins: const [],
      createdBy: null,
      pinnedMessageIds: (json['pinnedMessageIds'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      peerOnline: peer?['online'] == true,
      peerLastSeen: peer?['lastSeen']?.toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      pinned: json['pinned'] == true,
    );
  }

  static String _formatTime(String? iso) {
    if (iso == null) return '';

    final dt = DateTime.tryParse(iso)?.toLocal();

    if (dt == null) return '';

    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');

    return '$h:$m';
  }
}