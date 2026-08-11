import 'package:flutter/material.dart';
import '../services/jitsi_service.dart';

class CallMessageCard extends StatelessWidget {
  final String roomName;
  final bool isVideo;

  const CallMessageCard({
    super.key,
    required this.roomName,
    required this.isVideo,
  });

  Future<void> openCall() async {
    await JitsiService.joinRoom(roomName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: openCall,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF262D31)
              : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF25D366),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.call,
              color: const Color(0xFF25D366),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isVideo
                    ? "Tap to join video call"
                    : "Tap to join voice call",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}