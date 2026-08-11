/*import 'dart:async';

import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  final bool isRecording;
  final Future<void> Function() onStartRecording;
  final Future<void> Function() onStopRecording;
  final Future<void> Function() onCancelRecording;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.isRecording,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late final VoidCallback _listener;

  bool _hasText = false;
  double _dragX = 0;

  bool _cancelRecording = false;

  final double _cancelDistance = 120;

  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();

    _hasText = widget.controller.text.trim().isNotEmpty;

    _listener = () {
      final value = widget.controller.text.trim().isNotEmpty;

      if (value != _hasText) {
        setState(() {
          _hasText = value;
        });
      }
    };

    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _seconds = 0;

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted) return;

        setState(() {
          _seconds++;
        });
      },
    );
  }

  void _stopTimer() {
    _timer?.cancel();

    if (mounted) {
      setState(() {
        _seconds = 0;
      });
    }
  }

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.image,
              color: theme.colorScheme.secondary,
            ),
            onPressed: widget.onPickImage,
          ),

          Expanded(
            child: widget.isRecording
                ? Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(
                    _cancelRecording
                        ? Icons.delete
                        : Icons.mic,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _cancelRecording
                        ? "Release to cancel"
                        : "← Swipe to cancel",
                    style: TextStyle(
                      color: _cancelRecording
                          ? Colors.red
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(_time),
                ],
              ),
            )
                : TextField(
              controller: widget.controller,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(
                  color: theme.hintColor,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF2F2F2),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => widget.onSend(),
            ),
          ),

          if (_hasText)
            IconButton(
              icon: Icon(
                Icons.send,
                color: theme.colorScheme.secondary,
              ),
              onPressed: widget.onSend,
            )
          else
            GestureDetector(
              onTap: () async {
                if (widget.isRecording) {
                  _stopTimer();
                  await widget.onStopRecording();
                } else {
                  _startTimer();
                  await widget.onStartRecording();
                }
              },

              onLongPressStart: (_) async {
                if (widget.isRecording) return;

                _dragX = 0;
                _cancelRecording = false;

                print("START LONG PRESS");

                _startTimer();

                await widget.onStartRecording();
              },

              onLongPressMoveUpdate: (details) {
                _dragX = details.offsetFromOrigin.dx;

                if (_dragX < -_cancelDistance) {
                  if (!_cancelRecording) {
                    setState(() {
                      _cancelRecording = true;
                    });
                  }
                } else {
                  if (_cancelRecording) {
                    setState(() {
                      _cancelRecording = false;
                    });
                  }
                }
              },

              onLongPressEnd: (_) async {
                if (!widget.isRecording) return;

                print("END LONG PRESS");

                _stopTimer();

                if (_cancelRecording) {

                  print("VOICE CANCELED");

                  await widget.onCancelRecording();

                  return;
                }

                await widget.onStopRecording();
              },

              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: widget.isRecording
                      ? Colors.red
                      : theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isRecording
                      ? Icons.stop
                      : Icons.mic,
                  color: Colors.white,
                ),
              ),
            )
        ],
      ),
    );
  }
}

 */