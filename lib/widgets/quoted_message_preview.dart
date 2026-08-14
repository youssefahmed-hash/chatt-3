import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/message_type.dart';

/// Small quoted preview shown inside a message that is a reply.
class QuotedMessagePreview extends StatelessWidget {
  final ReplyPreview? reply;
  final VoidCallback? onTap;

  const QuotedMessagePreview({super.key, this.reply, this.onTap});

  String _previewText() {
    if (reply == null) return 'Original message';
    switch (reply!.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.file:
        return '📎 ${reply!.fileName ?? 'File'}';
      case MessageType.video:
        return '🎬 Video';
      case MessageType.videoCall:
        return '📹 Video call';
      case MessageType.voiceCall:
        return '📞 Voice call';
      case MessageType.text:
        return reply!.text.isEmpty ? 'Message' : reply!.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = _previewText();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.secondary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reply?.senderName == null || reply!.senderName!.isEmpty
                  ? 'Reply'
                  : reply!.senderName!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
