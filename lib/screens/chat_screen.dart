import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'group_info_screen.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/jitsi_service.dart';
import '../services/audio_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat/message_input.dart';
import '../config/api_config.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController controller =
  TextEditingController();

  final ScrollController _scrollController =
  ScrollController();

  final ImagePicker _picker =
  ImagePicker();

  // ============================================================
  // MESSAGES
  // ============================================================

  final List<Message> _messages = [];

  // ============================================================
  // AUDIO
  // ============================================================

  final AudioService _audioService =
  AudioService();

  bool _isRecording = false;

  DateTime? _recordStart;

  // ============================================================
  // LOADING
  // ============================================================

  bool _loading = true;

  // ============================================================
  // SOCKET SUBSCRIPTIONS
  // ============================================================

  StreamSubscription<NewMessageEvent>?
  _msgSub;

  StreamSubscription<DeletedMessageEvent>?
  _deleteSub;

  StreamSubscription<GroupUpdatedEvent>?
  _groupUpdatedSub;

  StreamSubscription<CallAcceptedEvent>?
  _callAcceptedSub;

  StreamSubscription<CallRejectedEvent>?
  _callRejectedSub;

  // ============================================================
  // CONVERSATION ID
  // ============================================================

  String? get _conversationId =>
      widget.chat.id;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _messages.addAll(
      widget.chat.messages,
    );

    _loadMessages();

    _listenForMessages();

    _listenForDeletedMessages();

    _listenForGroupUpdates();

    _listenForCallEvents();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _msgSub?.cancel();

    _deleteSub?.cancel();

    _groupUpdatedSub?.cancel();

    _callAcceptedSub?.cancel();

    _callRejectedSub?.cancel();

    controller.dispose();

    _scrollController.dispose();

    _audioService.dispose();

    super.dispose();
  }

  // ============================================================
  // GROUP UPDATES
  // ============================================================

  void _listenForGroupUpdates() {
    _groupUpdatedSub =
        SocketService.instance
            .onGroupUpdated
            .listen((event) {
          if (event.conversationId !=
              _conversationId) {
            return;
          }

          if (!mounted) return;

          setState(() {
            widget.chat.name =
                event.groupName;
          });
        });
  }

  // ============================================================
  // START RECORDING
  // ============================================================

  Future<void> _startRecording() async {
    try {
      debugPrint(
        'START RECORDING',
      );

      final path =
      await _audioService.startRecording();

      // لو permission مرفوضة
      if (path == null) {
        debugPrint(
          'Recording permission denied',
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordStart =
            DateTime.now();
      });

      debugPrint(
        'RECORDING STARTED',
      );
    } catch (e) {
      debugPrint(
        'START RECORDING ERROR: $e',
      );
    }
  }

  // ============================================================
  // STOP RECORDING
  // ============================================================

  Future<void> _stopRecording() async {
    try {
      debugPrint(
        'STOP RECORDING',
      );

      final path =
      await _audioService.stopRecording();

      debugPrint(
        'Recording path: $path',
      );

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      if (path == null) {
        return;
      }

      final conversationId =
          _conversationId;

      if (conversationId == null) {
        return;
      }

      final start =
          _recordStart;

      if (start == null) {
        return;
      }

      final duration =
          DateTime.now()
              .difference(start)
              .inSeconds;

      debugPrint(
        'Recording duration: $duration',
      );

      await ApiService.sendVoice(
        conversationId,
        XFile(path),
        duration,
      );

      debugPrint(
        'VOICE SENT',
      );

      _recordStart = null;
    } catch (e) {
      debugPrint(
        'STOP RECORDING ERROR: $e',
      );

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  // ============================================================
  // CANCEL RECORDING
  // ============================================================

  Future<void> _cancelRecording() async {
    try {
      debugPrint(
        'CANCEL RECORDING',
      );

      await _audioService
          .cancelRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      _recordStart = null;
    } catch (e) {
      debugPrint(
        'CANCEL RECORDING ERROR: $e',
      );

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  // ============================================================
  // PAUSE RECORDING
  // ============================================================

  Future<void> _pauseRecording() async {
    try {
      debugPrint(
        'PAUSE RECORDING',
      );

      await _audioService
          .pauseRecording();
    } catch (e) {
      debugPrint(
        'PAUSE RECORDING ERROR: $e',
      );
    }
  }

  // ============================================================
  // RESUME RECORDING
  // ============================================================

  Future<void> _resumeRecording() async {
    try {
      debugPrint(
        'RESUME RECORDING',
      );

      await _audioService
          .resumeRecording();
    } catch (e) {
      debugPrint(
        'RESUME RECORDING ERROR: $e',
      );
    }
  }

  // ============================================================
  // LOAD MESSAGES
  // ============================================================

  Future<void> _loadMessages() async {
    final id =
        _conversationId;

    if (id == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      return;
    }

    try {
      final messages =
      await ApiService
          .getMessages(id);

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);

        _loading = false;
      });

      _scrollToBottom();

      // Mark peer messages as read.
      if (widget.chat.peerId != null) {
        SocketService.instance
            .markRead(
          conversationId: id,
          peerId:
          widget.chat.peerId!,
        );
      }
    } catch (e) {
      debugPrint(
        'LOAD MESSAGES ERROR: $e',
      );

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickImage() async {
    final XFile? image =
    await _picker.pickImage(
      source:
      ImageSource.gallery,
    );

    if (image == null) return;

    final conversationId =
        _conversationId;

    if (conversationId == null) {
      return;
    }

    try {
      await ApiService.sendImage(
        conversationId,
        image,
      );

      debugPrint(
        'Image uploaded successfully',
      );
    } catch (e) {
      debugPrint(
        'Upload failed: $e',
      );
    }
  }

  // ============================================================
  // NEW MESSAGES
  // ============================================================

  void _listenForMessages() {
    _msgSub =
        SocketService.instance
            .onNewMessage
            .listen((event) {
          if (event.conversationId !=
              _conversationId) {
            return;
          }

          if (!mounted) return;

          setState(() {
            _messages.add(
              event.message,
            );
          });

          _scrollToBottom();
        });
  }

  // ============================================================
  // CALL EVENTS
  // ============================================================

  void _listenForCallEvents() {
    // ----------------------------------------------------------
    // CALL ACCEPTED
    // ----------------------------------------------------------

    _callAcceptedSub =
        SocketService.instance
            .onCallAccepted
            .listen((event) async {
          debugPrint(
            'CALL ACCEPTED EVENT',
          );

          debugPrint(
            event.roomName,
          );

          await JitsiService
              .joinRoom(
            event.roomName,
          );
        });

    // ----------------------------------------------------------
    // CALL REJECTED
    // ----------------------------------------------------------

    _callRejectedSub =
        SocketService.instance
            .onCallRejected
            .listen((_) {
          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content:
              Text('Call rejected'),
            ),
          );
        });
  }

  // ============================================================
  // SCROLL TO BOTTOM
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_scrollController
          .hasClients) {
        return;
      }

      _scrollController.jumpTo(
        _scrollController
            .position
            .maxScrollExtent,
      );
    });
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  void sendMessage() {
    final text =
    controller.text.trim();

    final id =
        _conversationId;

    if (text.isEmpty ||
        id == null) {
      return;
    }

    debugPrint(
      'conversationId = $id',
    );

    debugPrint(
      'text = $text',
    );

    SocketService.instance
        .sendMessage(
      conversationId: id,
      text: text,
    );

    widget.chat.lastMessage =
        text;

    controller.clear();
  }

  // ============================================================
  // SEND CALL
  // ============================================================

  void _sendCall(
      MessageType type,
      ) {
    debugPrint(
      'START CALL',
    );

    final id =
        _conversationId;

    if (id == null) return;

    final roomName =
        'chatt_$id';

    SocketService.instance
        .startCall(
      conversationId: id,
      roomName: roomName,
      type: type,
    );
  }

  // ============================================================
  // DELETE MESSAGE
  // ============================================================

  Future<void> deleteMessage(
      int index,
      ) async {
    final message =
    _messages[index];

    if (message.id == null) {
      debugPrint(
        'Message has no id',
      );

      return;
    }

    try {
      await ApiService
          .deleteMessage(
        message.id!,
      );

      debugPrint(
        'Message deleted successfully',
      );
    } catch (e) {
      debugPrint(
        'Delete failed: $e',
      );
    }
  }

  // ============================================================
  // DELETED MESSAGES
  // ============================================================

  void _listenForDeletedMessages() {
    _deleteSub =
        SocketService.instance
            .onDeletedMessage
            .listen((event) {
          if (event.conversationId !=
              _conversationId) {
            return;
          }

          if (!mounted) return;

          setState(() {
            _messages.removeWhere(
                  (message) =>
              message.id ==
                  event.messageId,
            );

            if (_messages.isNotEmpty) {
              widget.chat.lastMessage =
                  _messages.last.text;
            } else {
              widget.chat.lastMessage =
              '';
            }
          });
        });
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

    return Scaffold(
      // ==========================================================
      // BACKGROUND
      // ==========================================================

      backgroundColor:
      theme.brightness ==
          Brightness.dark
          ? const Color(
        0xFF121212,
      )
          : const Color(
        0xFFECE5DD,
      ),

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // ----------------------------------------------------
            // GROUP
            // ----------------------------------------------------

            if (widget.chat.isGroup) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GroupInfoScreen(
                        chat:
                        widget.chat,
                      ),
                ),
              );

              return;
            }

            // ----------------------------------------------------
            // USER
            // ----------------------------------------------------

            if (widget.chat.peerId ==
                null) {
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    UserProfileScreen(
                      userId:
                      widget.chat.peerId!,
                    ),
              ),
            );
          },

          child: Row(
            children: [
              // --------------------------------------------------
              // AVATAR
              // --------------------------------------------------

              CircleAvatar(
                radius: 18,

                backgroundColor:
                theme
                    .colorScheme
                    .secondary,

                backgroundImage:
                widget.chat.isGroup &&
                    widget.chat
                        .groupImage !=
                        null &&
                    widget.chat
                        .groupImage!
                        .isNotEmpty
                    ? NetworkImage(
                  '${ApiConfig.baseUrl}'
                      '${widget.chat.groupImage}',
                )
                    : null,

                child:
                !(widget.chat
                    .isGroup &&
                    widget.chat
                        .groupImage !=
                        null &&
                    widget.chat
                        .groupImage!
                        .isNotEmpty)
                    ? Text(
                  widget.chat
                      .name[0]
                      .toUpperCase(),
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontWeight:
                    FontWeight.bold,
                  ),
                )
                    : null,
              ),

              const SizedBox(
                width: 12,
              ),

              // --------------------------------------------------
              // NAME
              // --------------------------------------------------

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    Text(
                      widget.chat.name,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style: TextStyle(
                        color: theme
                            .appBarTheme
                            .foregroundColor,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),

                    if (!widget
                        .chat.isGroup)
                      const Text(
                        'Tap to view profile',
                        style:
                        TextStyle(
                          fontSize: 11,
                          color:
                          Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        backgroundColor:
        theme.appBarTheme
            .backgroundColor,

        foregroundColor:
        theme.appBarTheme
            .foregroundColor,

        elevation: 0,

        // ========================================================
        // CALL BUTTONS
        // ========================================================

        actions: [
          IconButton(
            color: theme
                .appBarTheme
                .foregroundColor,
            icon: const Icon(
              Icons.call,
            ),
            onPressed: () {
              _sendCall(
                MessageType.voiceCall,
              );
            },
          ),

          IconButton(
            color: theme
                .appBarTheme
                .foregroundColor,
            icon: const Icon(
              Icons.videocam,
            ),
            onPressed: () {
              _sendCall(
                MessageType.videoCall,
              );
            },
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: Container(
        color:
        theme.scaffoldBackgroundColor,

        child: Column(
          children: [
            // ====================================================
            // MESSAGES
            // ====================================================

            Expanded(
              child: _loading
                  ? Center(
                child:
                CircularProgressIndicator(
                  color: theme
                      .colorScheme
                      .secondary,
                ),
              )
                  : ListView.builder(
                controller:
                _scrollController,

                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),

                itemCount:
                _messages.length,

                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  return MessageBubble(
                    message:
                    _messages[index],

                    onDelete:
                        () async {
                      await deleteMessage(
                        index,
                      );
                    },
                  );
                },
              ),
            ),

            // ====================================================
            // MESSAGE INPUT
            // ====================================================

            MessageInput(
              controller: controller,

              onSend: sendMessage,

              onPickImage: pickImage,

              isRecording: _isRecording,

              onStartRecording:
              _startRecording,

              onStopRecording:
              _stopRecording,

              onCancelRecording:
              _cancelRecording,

              onPauseRecording: () async {
                await _audioService.pauseRecording();
              },

              onResumeRecording: () async {
                await _audioService.resumeRecording();
              },

              waveformStream:
              _audioService.waveformStream,
            ),
          ],
        ),
      ),
    );
  }
}