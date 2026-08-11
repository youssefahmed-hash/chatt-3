import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final VoidCallback? onTap;

  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback?
  onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;

  final bool isRecording;

  final double dragX;

  const MicButton({
    super.key,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    required this.isRecording,
    required this.dragX,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,

      onLongPressStart: onLongPressStart,

      onLongPressMoveUpdate:
      onLongPressMoveUpdate,

      onLongPressEnd: onLongPressEnd,

      child: Transform.translate(
        offset: Offset(
          isRecording && dragX < 0
              ? dragX
              : 0,
          0,
        ),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
            theme.colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}