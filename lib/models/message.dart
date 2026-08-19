import 'message_type.dart';

/// Delivery state of an outgoing message, shown as WhatsApp-style ticks.
enum MessageStatus { pending, delivered, read }

/// A reply snapshot (lightweight copy of the original message).
class ReplyPreview {
  final String? id;
  final String text;
  final MessageType type;
  final String? senderName;
  final String? imageUrl;
  final String? voiceUrl;
  final String? fileName;

  ReplyPreview({
    this.id,
    required this.text,
    required this.type,
    this.senderName,
    this.imageUrl,
    this.voiceUrl,
    this.fileName,
  });

  static ReplyPreview? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final sender = json['sender'] as Map<String, dynamic>?;
    return ReplyPreview(
      id: json['id']?.toString(),
      text: json['text'] ?? '',
      type: messageTypeFromString(json['type']),
      senderName: sender?['name'],
      imageUrl: json['imageUrl'],
      voiceUrl: json['voiceUrl'],
      fileName: json['fileName'],
    );
  }
}

class ReactionUser {
  final String id;
  final String? name;
  final String? avatarUrl;

  const ReactionUser({
    required this.id,
    this.name,
    this.avatarUrl,
  });

  static ReactionUser fromJson(Map<String, dynamic> json) => ReactionUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
  );
}

class ReactionSummary {
  final int count;
  final List<String> userIds;

  /// Who reacted with this emoji (id, name, avatar) — WhatsApp-style details.
  final List<ReactionUser> users;

  ReactionSummary({
    required this.count,
    required this.userIds,
    this.users = const [],
  });

  bool isReactedBy(String userId) => userIds.contains(userId);
}

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

  // محررة
  final bool edited;

  // الرد
  final String? replyToId;
  final ReplyPreview? replyTo;

  // معاد إرسالها
  final bool isForwarded;

  // ملفات
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileType;

  // فيديو
  final String? videoUrl;
  final String? videoThumbUrl;

  // التفاعلات
  final Map<String, ReactionSummary> reactions;
  final List<String> myReactions;

  // الحالة (علامات الصح)
  final MessageStatus status;

  // من قرأ الرسالة (readBy من الخادم)
  final List<String> readBy;

  // معرّف محلي من العميل للربط مع صدى الخادم
  final String? clientId;

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

    this.edited = false,

    this.replyToId,
    this.replyTo,

    this.isForwarded = false,

    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileType,

    this.videoUrl,
    this.videoThumbUrl,

    this.reactions = const {},
    this.myReactions = const [],

    this.status = MessageStatus.delivered,
    this.readBy = const [],
    this.clientId,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Postgres returns BIGINT columns (fileSize) as *strings* over the wire
  /// (e.g. "27"), so size fields must be parsed safely from either num or
  /// String, never cast blindly with `as num?`.
  static int? _toIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Message.fromJson(
      Map<String, dynamic> json,
      String myUserId,
      ) {
    final sender = json['sender'] as Map<String, dynamic>?;

    final senderId = sender?['id']?.toString();

    final reactionsRaw = json['reactions'] as Map<String, dynamic>? ?? {};

    final reactions = <String, ReactionSummary>{};
    reactionsRaw.forEach((emoji, value) {
      final v = value as Map<String, dynamic>;
      reactions[emoji] = ReactionSummary(
        count: (v['count'] as num?)?.toInt() ?? 0,
        userIds: (v['userIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
        users: (v['users'] as List?)
            ?.map((e) => ReactionUser.fromJson(e as Map<String, dynamic>))
            .toList() ??
            [],
      );
    });

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

      edited: json['edited'] == true,

      replyToId: json['replyToId']?.toString(),

      replyTo: ReplyPreview.tryParse(
        json['replyTo'] as Map<String, dynamic>?,
      ),

      isForwarded: json['forwardedFrom'] != null,

      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileSize: _toIntSafe(json['fileSize']),
      fileType: json['fileType'],

      videoUrl: json['videoUrl'],
      videoThumbUrl: json['videoThumbUrl'],

      reactions: reactions,

      myReactions: (json['myReactions'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          [],

      clientId: json['clientId']?.toString(),

      readBy: (json['readBy'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
    );
  }

  /// Returns a copy with the given fields replaced (all other fields carried
  /// over unchanged).
  Message copyWith({
    String? id,
    String? text,
    bool? isMe,
    MessageType? type,
    String? callUrl,
    String? imageUrl,
    String? voiceUrl,
    int? voiceDuration,
    DateTime? createdAt,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    bool? edited,
    String? replyToId,
    ReplyPreview? replyTo,
    bool? isForwarded,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileType,
    String? videoUrl,
    String? videoThumbUrl,
    Map<String, ReactionSummary>? reactions,
    List<String>? myReactions,
    MessageStatus? status,
    List<String>? readBy,
    String? clientId,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      type: type ?? this.type,
      callUrl: callUrl ?? this.callUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      createdAt: createdAt ?? this.createdAt,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      edited: edited ?? this.edited,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo ?? this.replyTo,
      isForwarded: isForwarded ?? this.isForwarded,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbUrl: videoThumbUrl ?? this.videoThumbUrl,
      reactions: reactions ?? this.reactions,
      myReactions: myReactions ?? this.myReactions,
      status: status ?? this.status,
      readBy: readBy ?? this.readBy,
      clientId: clientId ?? this.clientId,
    );
  }
}
