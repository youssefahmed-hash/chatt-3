import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chatt/models/message.dart';
import 'package:chatt/models/message_type.dart';
import 'package:chatt/l10n/generated/app_localizations.dart';
import 'package:chatt/widgets/chat/voice_recorder_bar.dart';

import 'mic_button.dart';
import 'chat_text_field.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;

  final VoidCallback onSend;

  final VoidCallback onPickImage;

  final bool isRecording;

  final Future<void> Function()
  onStartRecording;

  final Future<void> Function()
  onStopRecording;

  final Future<void> Function()
  onCancelRecording;

  final Future<void> Function()
  onPauseRecording;

  final Future<void> Function()
  onResumeRecording;

  final Stream<double>? waveformStream;

  // ===== REPLY =====
  final ReplyPreview? reply;
  final VoidCallback? onCancelReply;

  // ===== EDIT =====
  final bool isEditing;
  final VoidCallback? onEditingDone;
  final VoidCallback? onCancelEditing;

  // ===== TYPING =====
  final VoidCallback? onTyping;

  // ===== FILES / VIDEOS =====
  final VoidCallback? onPickFile;
  final VoidCallback? onPickVideo;

  const MessageInput({
    super.key,

    required this.controller,

    required this.onSend,

    required this.onPickImage,

    required this.isRecording,

    required this.onStartRecording,

    required this.onStopRecording,

    required this.onCancelRecording,

    required this.onPauseRecording,

    required this.onResumeRecording,

    required this.waveformStream,

    this.reply,

    this.onCancelReply,

    this.isEditing = false,

    this.onEditingDone,

    this.onCancelEditing,

    this.onTyping,

    this.onPickFile,

    this.onPickVideo,
  });

  @override
  State<MessageInput> createState() =>
      _MessageInputState();
}

class _MessageInputState
    extends State<MessageInput> {
  late final VoidCallback _listener;

  bool _hasText = false;

  // ============================================================
  // RECORDING MODE
  // ============================================================

  // false = Short Press
  // true  = Long Press
  bool _longPressMode = false;

  // ============================================================
  // PAUSE
  // ============================================================

  bool _isPaused = false;

  // ============================================================
  // LONG PRESS DRAG
  // ============================================================

  double _dragX = 0;

  bool _isCanceling = false;

  static const double
  _cancelDistance = 270;

  // ============================================================
  // TIMER
  // ============================================================

  Timer? _timer;

  int _seconds = 0;

  // ============================================================
  // WAVEFORM
  // ============================================================

  StreamSubscription<double>?
  _waveformSubscription;

  final List<double> _waveform = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _hasText =
        widget.controller.text
            .trim()
            .isNotEmpty;

    _listener = () {
      final value =
          widget.controller.text
              .trim()
              .isNotEmpty;

      widget.onTyping?.call();

      if (value != _hasText &&
          mounted) {
        setState(() {
          _hasText = value;
        });
      }
    };

    widget.controller
        .addListener(_listener);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    widget.controller
        .removeListener(_listener);

    _timer?.cancel();

    _waveformSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // WAVEFORM
  // ============================================================

  void _startWaveform() {
    _waveform.clear();

    _waveformSubscription
        ?.cancel();

    final stream =
        widget.waveformStream;

    if (stream == null) {
      return;
    }

    // Long Press never starts waveform.
    if (_longPressMode) {
      return;
    }

    _waveformSubscription =
        stream.listen(
              (value) {
            if (!mounted) return;

            // حماية إضافية:
            // Long Press ممنوع waveform.
            if (_longPressMode) {
              return;
            }

            final normalized =
            value
                .clamp(0.0, 1.0)
                .toDouble();

            setState(() {
              _waveform
                  .add(normalized);

              if (_waveform.length >
                  60) {
                _waveform.removeAt(0);
              }
            });
          },
        );
  }

  Future<void>
  _stopWaveform() async {
    await _waveformSubscription
        ?.cancel();

    _waveformSubscription = null;
  }

  // ============================================================
  // TIMER
  // ============================================================

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

    _timer = null;

    if (mounted) {
      setState(() {
        _seconds = 0;
      });
    }
  }

  String get _time {
    final hours = _seconds >= 3600
        ? (_seconds ~/ 3600).toString().padLeft(2, '0')
        : null;

    final minutes = ((_seconds ~/ 60) % 60)
        .toString()
        .padLeft(2, '0');

    final seconds =
    (_seconds % 60)
        .toString()
        .padLeft(2, '0');

    return hours == null
        ? '$minutes:$seconds'
        : '$hours:$minutes:$seconds';
  }

  // ============================================================
  // RESET
  // ============================================================

  void _resetRecordingUI() {
    if (!mounted) return;

    setState(() {
      _dragX = 0;

      _isCanceling = false;

      _longPressMode = false;

      _isPaused = false;

      _waveform.clear();
    });
  }

  // ============================================================
  // SHORT PRESS
  //
  // أول ضغطة:
  // Start recording
  //
  // أثناء التسجيل:
  // Pause / Resume
  // ============================================================

  Future<void>
  _handleTap() async {
    // ==========================================================
    // START
    // ==========================================================

    if (!widget.isRecording) {
      if (!mounted) return;

      setState(() {
        _longPressMode = false;

        _dragX = 0;

        _isCanceling = false;

        _isPaused = false;
      });

      _startTimer();

      await widget
          .onStartRecording();

      if (!mounted) return;

      _startWaveform();

      return;
    }

    // ==========================================================
    // LONG PRESS DOES NOT PAUSE
    // ==========================================================

    if (_longPressMode) {
      return;
    }

    // ==========================================================
    // SHORT PRESS = PAUSE / RESUME
    // ==========================================================

    await _stopWaveform();

    if (_isPaused) {
      await widget
          .onResumeRecording();

      if (!mounted) return;

      setState(() {
        _isPaused = false;
      });

      _startWaveform();
    } else {
      await widget
          .onPauseRecording();

      if (!mounted) return;

      setState(() {
        _isPaused = true;
      });
    }
  }

  // ============================================================
  // LONG PRESS START
  //
  // IMPORTANT:
  // No waveform here.
  // ============================================================

  Future<void>
  _handleLongPressStart(
      LongPressStartDetails details,
      ) async {
    if (widget.isRecording) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _longPressMode = true;

      _dragX = 0;

      _isCanceling = false;

      _isPaused = false;

      _waveform.clear();
    });

    // Ensure waveform is not running.
    await _stopWaveform();

    _startTimer();

    await widget
        .onStartRecording();

    // لا يوجد _startWaveform()
    //
    // Long Press بدون waveform.
  }

  // ============================================================
  // LONG PRESS MOVE
  // ============================================================

  void _handleLongPressMove(
      LongPressMoveUpdateDetails
      details,
      ) {
    if (!widget.isRecording) {
      return;
    }

    if (!_longPressMode) {
      return;
    }

    final currentDragX =
        details.offsetFromOrigin.dx;

    // الشمال فقط
    final newDragX =
    currentDragX < 0
        ? currentDragX
        : 0.0;

    final shouldCancel =
        newDragX <=
            -_cancelDistance;

    if (!mounted) return;

    setState(() {
      _dragX = newDragX;

      _isCanceling =
          shouldCancel;
    });
  }

  // ============================================================
  // LONG PRESS END
  // ============================================================

  Future<void>
  _handleLongPressEnd(
      LongPressEndDetails details,
      ) async {
    if (!widget.isRecording) {
      _resetRecordingUI();
      return;
    }

    if (!_longPressMode) {
      return;
    }

    final shouldCancel =
        _isCanceling;

    _stopTimer();

    await _stopWaveform();

    // ==========================================================
    // CANCEL
    // ==========================================================

    if (shouldCancel) {
      await widget
          .onCancelRecording();

      _resetRecordingUI();

      return;
    }

    // ==========================================================
    // SEND
    // ==========================================================

    await widget
        .onStopRecording();

    _resetRecordingUI();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    // ==========================================================
    // MIC
    // ==========================================================

    final showMicButton =
        !_hasText &&
            (!widget.isRecording ||
                _longPressMode);

    // ==========================================================
    // SHORT PRESS RECORDER
    // ==========================================================

    final showRecorderBar =
        widget.isRecording &&
            !_longPressMode;

    // ==========================================================
    // LONG PRESS
    // ==========================================================

    final showLongPress =
        widget.isRecording &&
            _longPressMode;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),

      decoration:
      BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E1E)
            : Colors.white,

        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ======================================================
          // REPLY PREVIEW BAR
          // ======================================================
          if (widget.reply != null)
            _buildReplyBar(theme),

          // ======================================================
          // EDITING BAR
          // ======================================================
          if (widget.isEditing)
            _buildEditingBar(theme),

          Stack(
            clipBehavior:
            Clip.none,

        children: [
          // ======================================================
          // MAIN ROW
          // ======================================================

          Row(
            children: [
              // ====================================================
              // ATTACH (FILES)
              // ====================================================

              if (!showRecorderBar)
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: theme
                        .colorScheme
                        .secondary,
                  ),
                  onPressed: widget.onPickFile,
                ),

              // ====================================================
              // VIDEO
              // ====================================================

              if (!showRecorderBar)
                IconButton(
                  icon: Icon(
                    Icons.videocam,
                    color: theme
                        .colorScheme
                        .secondary,
                  ),
                  onPressed: widget.onPickVideo,
                ),

              // ====================================================
              // IMAGE
              // ====================================================

              if (!showRecorderBar)
                IconButton(
                  icon: Icon(
                    Icons.image,
                    color: theme
                        .colorScheme
                        .secondary,
                  ),
                  onPressed:
                  widget.onPickImage,
                ),

              // ====================================================
              // CENTER
              // ====================================================

              Expanded(
                child: Stack(
                  alignment:
                  Alignment.centerLeft,

                  children: [
                    // =================================================
                    // SHORT PRESS RECORDER
                    // =================================================

                    AnimatedOpacity(
                      duration:
                      const Duration(
                        milliseconds: 150,
                      ),

                      opacity:
                      showRecorderBar
                          ? 1
                          : 0,

                      child:
                      IgnorePointer(
                        ignoring:
                        !showRecorderBar,

                        child:
                        VoiceRecorderBar(
                          time: _time,

                          waveform:
                          _waveform,

                          isPaused:
                          _isPaused,

                          onPause:
                              () async {
                            await _stopWaveform();

                            await widget
                                .onPauseRecording();

                            if (!mounted) {
                              return;
                            }

                            setState(() {
                              _isPaused =
                              true;
                            });
                          },

                          onResume:
                              () async {
                            await widget
                                .onResumeRecording();

                            if (!mounted) {
                              return;
                            }

                            setState(() {
                              _isPaused =
                              false;
                            });

                            _startWaveform();
                          },

                          onCancel:
                              () async {
                            _stopTimer();

                            await _stopWaveform();

                            await widget
                                .onCancelRecording();

                            _resetRecordingUI();
                          },

                          onSend:
                              () async {
                            _stopTimer();

                            await _stopWaveform();

                            await widget
                                .onStopRecording();

                            _resetRecordingUI();
                          },
                        ),
                      ),
                    ),

                    // =================================================
                    // LONG PRESS UI
                    //
                    // No waveform.
                    // =================================================

                    AnimatedOpacity(
                      duration:
                      const Duration(
                        milliseconds: 100,
                      ),

                      opacity:
                      showLongPress
                          ? 1
                          : 0,

                      child:
                      IgnorePointer(
                        ignoring:
                        !showLongPress,

                        child:
                        SizedBox(
                          height: 76,

                          child: Row(
                            children: [
                              const SizedBox(
                                width: 12,
                              ),

                              // ======================================
                              // TIMER
                              // ======================================

                              Text(
                                _time,

                                style:
                                TextStyle(
                                  color: theme
                                      .textTheme
                                      .bodyLarge
                                      ?.color,

                                  fontSize: 13,

                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),

                              const SizedBox(
                                width: 15,
                              ),

                              // ======================================
                              // SWIPE TEXT
                              // ======================================

                              Expanded(
                                child:
                                AnimatedSwitcher(
                                  duration:
                                  const Duration(
                                    milliseconds:
                                    150,
                                  ),

                                  child:
                                  Text(
                                    _isCanceling
                                        ? AppLocalizations.of(context).recordingCancelHint
                                        : AppLocalizations.of(context).recordingSendHint,

                                    key:
                                    ValueKey(
                                      _isCanceling,
                                    ),

                                    textAlign:
                                    TextAlign
                                        .center,

                                    maxLines: 1,

                                    overflow:
                                    TextOverflow
                                        .ellipsis,

                                    style:
                                    TextStyle(
                                      color:
                                      _isCanceling
                                          ? Colors.red
                                          : Colors.grey,

                                      fontSize:
                                      12,

                                      fontWeight:
                                      _isCanceling
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 60,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // =================================================
                    // TEXT FIELD
                    // =================================================

                    AnimatedOpacity(
                      duration:
                      const Duration(
                        milliseconds: 150,
                      ),

                      opacity:
                      widget.isRecording
                          ? 0
                          : 1,

                      child:
                      IgnorePointer(
                        ignoring:
                        widget.isRecording,

                        child:
                        ChatTextField(
                          controller:
                          widget.controller,

                          onSend:
                          widget.onSend,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ====================================================
              // SEND TEXT
              // ====================================================

              SizedBox(
                width: 56,

                child: _hasText
                    ? IconButton(
                  icon: Icon(
                    widget.isEditing
                        ? Icons.check
                        : Icons.send,

                    color: theme
                        .colorScheme
                        .secondary,
                  ),

                  onPressed: widget.isEditing
                      ? widget.onEditingDone
                      : widget.onSend,
                )
                    : const SizedBox(),
              ),
            ],
          ),

          // ==========================================================
          // LONG PRESS MIC
          //
          // ده اللي بيتحرك.
          // ==========================================================

          if (showMicButton)
            Positioned(
              right: 4,
              bottom: 9.9,

              child: MicButton(
                isRecording:
                widget.isRecording,

                dragX: _dragX,

                onTap:
                _handleTap,

                onLongPressStart:
                _handleLongPressStart,

                onLongPressMoveUpdate:
                _handleLongPressMove,

                onLongPressEnd:
                _handleLongPressEnd,
              ),
            ),
        ],
      ),
    ],
  ),
  );
  }

  // ============================================================
  // REPLY BAR
  // ============================================================

  Widget _buildReplyBar(ThemeData theme) {
    final reply = widget.reply!;

    String preview = '';
    switch (reply.type) {
      case MessageType.image:
        preview = '📷 Photo';
        break;
      case MessageType.voice:
        preview = '🎤 Voice message';
        break;
      case MessageType.file:
        preview = '📎 ${reply.fileName ?? 'File'}';
        break;
      case MessageType.video:
        preview = '🎬 Video';
        break;
      case MessageType.videoCall:
        preview = '📹 Video call';
        break;
      case MessageType.voiceCall:
        preview = '📞 Voice call';
        break;
      case MessageType.text:
        preview = reply.text.isEmpty ? 'Message' : reply.text;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.secondary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reply.senderName == null || reply.senderName!.isEmpty
                      ? AppLocalizations.of(context).reply
                      : reply.senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDITING BAR
  // ============================================================

  Widget _buildEditingBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).editingMessage,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelEditing,
          ),
        ],
      ),
    );
  }
}