/*import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chatt/widgets/chat/voice_recorder_bar.dart';
import 'mic_button.dart';
import 'chat_text_field.dart';

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

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _seconds++;
      });
    });
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.image, color: theme.colorScheme.secondary),
                onPressed: widget.onPickImage,
              ),

              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: widget.isRecording ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !widget.isRecording,
                        child: VoiceRecorderBar(
                          time: _time,
                          dragX: _dragX,
                          cancelRecording: _cancelRecording,
                        ),
                      ),
                    ),

                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: widget.isRecording ? 0 : 1,
                      child: IgnorePointer(
                          ignoring: widget.isRecording,
                          child: ChatTextField(
                            controller: widget.controller,
                            onSend: widget.onSend,
                          )
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 56,
                child: _hasText
                    ? IconButton(
                  icon: Icon(
                    Icons.send,
                    color: theme.colorScheme.secondary,
                  ),
                  onPressed: widget.onSend,
                )
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
 */
