import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import 'call_message_card.dart';
import '../screens/full_screen_image.dart';
import '../config/api_config.dart';
import 'voice_message_player.dart';
import 'quoted_message_preview.dart';
import 'file_message_card.dart';
import 'video_message_player.dart';
import 'reaction_bar.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onForward;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final VoidCallback? onStar;
  final VoidCallback? onUnstar;
  final ValueChanged<String>? onReaction;
  final ValueChanged<String>? onReactionDetails;
  final VoidCallback? onTapReply;
  final bool isPinned;
  final bool isStarred;
  final bool canPin;

  const MessageBubble({
    super.key,
    required this.message,
    this.onDelete,
    this.onReply,
    this.onEdit,
    this.onForward,
    this.onPin,
    this.onUnpin,
    this.onStar,
    this.onUnstar,
    this.onReaction,
    this.onReactionDetails,
    this.onTapReply,
    this.isPinned = false,
    this.isStarred = false,
    this.canPin = false,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showActions(BuildContext context, {required bool isMe}) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final actions = <Widget>[
      ListTile(
        leading: const Icon(Icons.reply),
        title: Text(l10n.reply),
        onTap: () {
          Navigator.pop(context);
          onReply?.call();
        },
      ),
      ListTile(
        leading: const Icon(Icons.add_reaction_outlined),
        title: Text(l10n.react),
        onTap: () {
          Navigator.pop(context);
          onReaction?.call('');
        },
      ),
      ListTile(
        leading: const Icon(Icons.forward),
        title: Text(l10n.forward),
        onTap: () {
          Navigator.pop(context);
          onForward?.call();
        },
      ),
      ListTile(
        leading: Icon(isStarred ? Icons.star : Icons.star_border),
        title: Text(isStarred ? l10n.unstar : l10n.star),
        onTap: () {
          Navigator.pop(context);
          (isStarred ? onUnstar : onStar)?.call();
        },
      ),
      if (canPin)
        ListTile(
          leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
          title: Text(isPinned ? l10n.unpin : l10n.pin),
          onTap: () {
            Navigator.pop(context);
            (isPinned ? onUnpin : onPin)?.call();
          },
        ),
      if (isMe && message.type == MessageType.text)
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(l10n.edit),
          onTap: () {
            Navigator.pop(context);
            onEdit?.call();
          },
        ),
      if (isMe)
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            _confirmDelete(context);
          },
        ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogTheme.backgroundColor,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        title: Text(l10n.deleteMessage),
        content: Text(l10n.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isGroupMessage =
        message.senderName != null &&
            message.senderName!.isNotEmpty;

    if (message.type == MessageType.videoCall ||
        message.type == MessageType.voiceCall) {
      return Align(
        alignment:
        isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: CallMessageCard(
          roomName: message.callUrl!,
          isVideo:
          message.type == MessageType.videoCall,
        ),
      );
    }

    final maxWidth =
        MediaQuery.of(context).size.width * 0.75;

    // WhatsApp-style reactions: pills float OUTSIDE the bubble, anchored at
    // the bottom corner. The bubble then hugs its content and never grows to
    // fit the reaction bar.
    final hasReactions =
        message.reactions.values.any((r) => r.count > 0) ||
            message.myReactions.isNotEmpty;

    return _ReplySwipeDetector(
      onLongPress: () => _showActions(context, isMe: isMe),
      onReply: onReply,
      child: Align(
        alignment:
        isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: hasReactions ? 16 : 3,
            top: 1,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 3,
                  ),
                  padding:
                  const EdgeInsets.fromLTRB(9, 6, 9, 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isDark
                        ? const Color(0xFF056162)
                        : const Color(0xFFDCF8C6))
                        : (isDark
                        ? const Color(0xFF262D31)
                        : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(10),
                      topRight: const Radius.circular(10),
                      bottomLeft: Radius.circular(
                        (!isMe && hasReactions) ? 10 : (isMe ? 10 : 2),
                      ),
                      bottomRight: Radius.circular(
                        (isMe && hasReactions) ? 10 : (isMe ? 2 : 10),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.55 : 0.14,
                        ),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMe && isGroupMessage)
                        Padding(
                          padding:
                          const EdgeInsets.only(bottom: 3),
                          child: Text(
                            message.senderName!,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary,
                              fontWeight:
                              FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),

                      // ===== الرد =====
                      if (message.replyTo != null)
                        QuotedMessagePreview(
                          reply: message.replyTo,
                          onTap: onTapReply,
                        ),

                      // ===== Forwarded label =====
                      if (message.isForwarded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            AppLocalizations.of(context).forwardedLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),

                      // ===== محتوى الرسالة =====
                      if (message.type == MessageType.image)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FullScreenImage(
                                      imageUrl: message
                                          .imageUrl!
                                          .startsWith(
                                          'http')
                                          ? message.imageUrl!
                                          : "${ApiConfig.baseUrl}${message.imageUrl}",
                                    ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius:
                            BorderRadius.circular(8),
                            child: Image.network(
                              message.imageUrl!
                                  .startsWith("http")
                                  ? message.imageUrl!
                                  : "${ApiConfig.baseUrl}${message.imageUrl}",
                              width: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )

                      else if (message.type == MessageType.voice)
                        VoiceMessagePlayer(
                          url: message.voiceUrl!
                              .startsWith("http")
                              ? message.voiceUrl!
                              : "${ApiConfig.baseUrl}${message.voiceUrl}",
                          duration:
                          message.voiceDuration,
                        )

                      else if (message.type == MessageType.file)
                        FileMessageCard(
                          url: message.fileUrl,
                          fileName: message.fileName,
                          fileSize: message.fileSize,
                          fileType: message.fileType,
                        )

                      else if (message.type == MessageType.video)
                        VideoMessagePlayer(
                          url: message.videoUrl!,
                          thumbUrl: message.videoThumbUrl,
                        )

                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            message.text,
                            textAlign:
                            message.text.length > 50
                                ? TextAlign.start
                                : TextAlign.end,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ),

                      // ===== Timestamp + status ticks =====
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                        CrossAxisAlignment.center,
                        children: [
                          if (message.edited)
                            Padding(
                              padding:
                              const EdgeInsets.only(right: 4),
                              child: Text(
                                AppLocalizations.of(context).editedLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white60
                                  : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                          if (message.isMe) ...[
                            const SizedBox(width: 3),
                            _CheckMarks(status: message.status),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (hasReactions)
                Positioned(
                  bottom: -11,
                  left: isMe ? null : 8,
                  right: isMe ? 8 : null,
                  child: ReactionBar(
                    reactions: message.reactions,
                    myReactions: message.myReactions,
                    emojis: const [],
                    onTap: onReaction ?? (_) {},
                    onLongTap: onReactionDetails,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a message bubble and triggers [onReply] when the user swipes the
/// bubble to the right past a small threshold.
class _ReplySwipeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final GestureLongPressCallback? onLongPress;

  const _ReplySwipeDetector({
    required this.child,
    this.onReply,
    this.onLongPress,
  });

  @override
  State<_ReplySwipeDetector> createState() => _ReplySwipeDetectorState();
}

class _ReplySwipeDetectorState extends State<_ReplySwipeDetector> {
  static const _threshold = 60.0;
  double _dx = 0;

  void _reset() {
    if (_dx != 0) setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: (details) {
        setState(() => _dx += details.delta.dx);
      },
      onHorizontalDragEnd: (_) {
        if (_dx > _threshold && widget.onReply != null) {
          widget.onReply!.call();
        }
        _reset();
      },
      onHorizontalDragCancel: _reset,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: _dx > 0 ? Matrix4.translationValues(_dx.clamp(0, 48), 0, 0) : null,
        child: widget.child,
      ),
    );
  }
}

/// WhatsApp-style delivery ticks for outgoing messages.
class _CheckMarks extends StatelessWidget {
  final MessageStatus status;

  const _CheckMarks({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingColor = isDark ? Colors.white38 : Colors.grey.shade400;
    final deliveredColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final readColor = const Color(0xFF53BDEB);

    switch (status) {
      case MessageStatus.pending:
        // One gray tick — created locally, delivery not yet confirmed.
        return Icon(Icons.done, size: 14, color: pendingColor);
      case MessageStatus.delivered:
        // Two gray ticks — persisted on the server.
        return Icon(Icons.done_all, size: 14, color: deliveredColor);
      case MessageStatus.read:
        // Two blue ticks — read by the recipient.
        return Icon(Icons.done_all, size: 14, color: readColor);
    }
  }
}
