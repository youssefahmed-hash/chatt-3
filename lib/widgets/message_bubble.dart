import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import 'call_message_card.dart';
import '../screens/full_screen_image.dart';
import '../config/api_config.dart';
import 'voice_message_player.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.onDelete,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

    return GestureDetector(
      onLongPress: () {
        if (!isMe) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor:
            theme.dialogTheme.backgroundColor,
            title: const Text("Delete Message"),
            content: const Text(
              "Are you sure you want to delete this message?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color:
                    theme.colorScheme.secondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: Align(
        alignment:
        isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(
              vertical: 3,
              horizontal: 4,
            ),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe
                  ? (isDark
                  ? const Color(0xFF056162)
                  : const Color(0xFFDCF8C6))
                  : (isDark
                  ? const Color(0xFF262D31)
                  : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft:
                Radius.circular(isMe ? 12 : 2),
                bottomRight:
                Radius.circular(isMe ? 2 : 12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    isDark ? 0.35 : 0.12,
                  ),
                  blurRadius: 2,
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
                    const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName!,
                      style: TextStyle(
                        color: theme
                            .colorScheme.secondary,
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // ===== محتوى الرسالة =====

                if (message.type ==
                    MessageType.image)
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
                      BorderRadius.circular(10),
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

                else if (message.type ==
                    MessageType.voice)
                  VoiceMessagePlayer(
                    url: message.voiceUrl!
                        .startsWith("http")
                        ? message.voiceUrl!
                        : "${ApiConfig.baseUrl}${message.voiceUrl}",
                    duration:
                    message.voiceDuration,
                  )

                else
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 15,
                    ),
                  ),

                const SizedBox(height: 4),

                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isDark
                        ? Colors.white60
                        : Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}