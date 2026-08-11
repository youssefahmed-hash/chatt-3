import 'message_type.dart';

class Message {
  final String? id;

  final String text;

  final bool isMe;

  final MessageType type;

  final String? callUrl;

  final String? imageUrl;

  final String? voiceUrl;

  final int voiceDuration;

  final DateTime createdAt;

  // جديد
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;

  Message({
    this.id,
    required this.text,
    required this.isMe,
    this.type = MessageType.text,
    this.callUrl,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration = 0,
    DateTime? createdAt,

    this.senderId,
    this.senderName,
    this.senderAvatar,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Message.fromJson(
      Map<String, dynamic> json,
      String myUserId,

      ) {
    final sender = json['sender'] as Map<String, dynamic>?;

    final senderId = sender?['id']?.toString();

    return Message(
      id: json['id']?.toString(),
      voiceUrl: json['voiceUrl'],
      voiceDuration: json['voiceDuration'] ?? 0,
      text: json['text'] ?? '',

      isMe: senderId == myUserId,

      type: messageTypeFromString(json['type']),

      callUrl: json['callUrl'],

      imageUrl: json['imageUrl'],

      createdAt:
      DateTime.tryParse(json['createdAt'] ?? '')
          ?.toLocal() ??
          DateTime.now(),

      senderId: senderId,

      senderName: sender?['name'],

      senderAvatar: sender?['avatarUrl'],
    );
  }
}