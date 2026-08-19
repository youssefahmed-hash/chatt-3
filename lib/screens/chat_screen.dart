import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'group_info_screen.dart';
import 'forward_screen.dart';
import 'pinned_messages_screen.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/jitsi_service.dart';
import '../services/audio_service.dart';
import '../services/offline_queue.dart';
import '../services/session.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat/message_input.dart';
import '../config/api_config.dart';
import 'user_profile_screen.dart';

const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '🎉'];

/// Insert or replace a message in [messages], first adopting any local pending
/// placeholder that shares the same [Message.clientId] (so the server echo of
/// an online/offline send upgrades one ✓ to two gray ✓✓ instead of
/// duplicating). [peerIds] is accepted for signature stability with the
/// caller, matching how the chat screen computes read state.
void upsertIntoList(
  List<Message> messages,
  Message incoming,
  List<String> peerIds,
) {
  final clientId = incoming.clientId;
  if (clientId != null && clientId.isNotEmpty) {
    final idx = messages.indexWhere(
      (m) => m.isMe && m.clientId == clientId,
    );
    if (idx != -1) {
      messages[idx] = incoming;
      return;
    }
  }

  // Incoming without a server id (no clientId adoption possible) adopts the
  // oldest pending placeholder so offline flushes never duplicate.
  if (incoming.isMe) {
    final pendingIdx = messages.indexWhere(
      (m) => m.isMe && m.status == MessageStatus.pending,
    );
    if (pendingIdx != -1) {
      messages[pendingIdx] = incoming;
      return;
    }
  }

  final id = incoming.id;
  if (id != null) {
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      messages[idx] = incoming;
      return;
    }
  }

  messages.add(incoming);
}

class ChatScreen extends StatefulWidget {
  final Chat chat;

  /// When set, the chat opens scrolled to this message (highlighted).
  final String? highlightMessageId;

  const ChatScreen({
    super.key,
    required this.chat,
    this.highlightMessageId,
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

  bool _showScrollDownButton = false;

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

  StreamSubscription<MessageEditedEvent>?
  _editSub;

  StreamSubscription<ReactionEvent>?
  _reactionAddSub;

  StreamSubscription<ReactionEvent>?
  _reactionRemoveSub;

  StreamSubscription<TypingEvent>?
  _typingSub;

  StreamSubscription<PresenceEvent>?
  _presenceSub;

  StreamSubscription<RecordingEvent>?
  _recordingStartSub;

  StreamSubscription<RecordingEvent>?
  _recordingStopSub;

  StreamSubscription<PinnedEvent>?
  _pinSub;

  StreamSubscription<PinnedEvent>?
  _unpinSub;

  StreamSubscription<ReadReceiptEvent>?
  _readSub;

  // ============================================================
  // REPLY / EDIT
  // ============================================================

  ReplyPreview? _replyTo;

  Message? _editingMessage;

  // ============================================================
  // PINNED / STARRED
  // ============================================================

  final Set<String> _pinnedIds = {};

  final Set<String> _starredIds = {};

  // ============================================================
  // TYPING / RECORDING / ONLINE
  // ============================================================

  Timer? _typingTimer;

  bool _peerTyping = false;

  bool _peerRecording = false;

  bool _peerOnline = false;

  // ============================================================
  // SEARCH
  // ============================================================

  bool _searching = false;

  final TextEditingController _searchController =
  TextEditingController();

  List<Message> _searchResults = [];

  bool _searchingLoading = false;

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

    _scrollController.addListener(_onScrollChanged);

    _messages.addAll(
      widget.chat.messages.map(_applyReadState),
    );

    _pinnedIds.addAll(widget.chat.pinnedMessageIds);

    _loadMessages();

    _listenForMessages();

    _listenForDeletedMessages();

    _listenForGroupUpdates();

    _listenForCallEvents();

    _listenForEditedMessages();

    _listenForReactions();

    _listenForTyping();

    _listenForPresence();

    _listenForRecordingIndicator();

    _listenForPins();

    _listenForReadReceipts();
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
    _editSub?.cancel();
    _reactionAddSub?.cancel();
    _reactionRemoveSub?.cancel();
    _typingSub?.cancel();
    _presenceSub?.cancel();
    _recordingStartSub?.cancel();
    _recordingStopSub?.cancel();
    _pinSub?.cancel();
    _unpinSub?.cancel();
    _readSub?.cancel();
    _typingTimer?.cancel();

    // Notify the peer that we stopped typing when leaving the screen.
    final id = _conversationId;
    if (id != null) {
      SocketService.instance.setTyping(
        conversationId: id,
        peerId: widget.chat.peerId ?? '',
        typing: false,
      );
    }

    controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();

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
          AppLocalizations.of(context).recordingPermissionDenied,
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordStart =
            DateTime.now();
      });

      final id = _conversationId;
      if (id != null) {
        SocketService.instance.setRecording(
          conversationId: id,
          recording: true,
        );
      }

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

      final id = _conversationId;
      if (id != null) {
        SocketService.instance.setRecording(
          conversationId: id,
          recording: false,
        );
      }

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

      final replyId = _replyTo?.id;

      final sent = await ApiService.sendVoice(
        conversationId,
        XFile(path),
        duration,
        replyToId: replyId,
      );

      if (mounted) {
        setState(() {
          _upsertMessage(sent);
          _replyTo = null;
        });
      }

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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).sendFailed} $e')),
        );
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

      final id = _conversationId;
      if (id != null) {
        SocketService.instance.setRecording(
          conversationId: id,
          recording: false,
        );
      }

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
      // Opening to a specific message (e.g. from pinned / search).
      if (widget.highlightMessageId != null) {
        final messages = await ApiService.getMessageContext(
          conversationId: id,
          messageId: widget.highlightMessageId!,
        );

        if (!mounted) return;

        setState(() {
          _messages
            ..clear()
            ..addAll(messages.map(_applyReadState));
          _loading = false;
        });

        _scrollToMessage(widget.highlightMessageId!);

        if (widget.chat.peerId != null) {
          SocketService.instance.markRead(
            conversationId: id,
            peerId: widget.chat.peerId!,
          );
        }
        return;
      }

      final messages =
      await ApiService
          .getMessages(id, limit: 100);

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(messages.map(_applyReadState));

        _loading = false;
      });

      _scrollToBottom();

      // Mark peer messages as read (direct chats id the peer; groups let the
      // server resolve all other participants).
      SocketService.instance
          .markRead(
        conversationId: id,
        peerId:
        widget.chat.peerId ?? '',
      );
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
      final sent = await ApiService.sendImage(
        conversationId,
        image,
        replyToId: _replyTo?.id,
      );

      if (mounted) {
        setState(() {
          _upsertMessage(sent);
          _replyTo = null;
        });
      }

      debugPrint(
        AppLocalizations.of(context).imageUploadedSuccess,
      );
    } catch (e) {
      debugPrint(
        'Upload failed: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).sendFailed} $e')),
        );
      }
    }
  }

  // ============================================================
  // PICK FILE
  // ============================================================

  Future<void> pickFile() async {
    // file_picker v12 returns a List<PlatformFile> directly,
    // not a FilePickerResult wrapper.
    final files = await FilePicker.pickFiles(
      withData: kIsWeb,
      allowMultiple: false,
    );

    if (files.isEmpty) return;

    final file = files.first;

    final XFile? xfile;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      xfile = XFile.fromData(bytes, name: file.name);
    } else {
      final path = file.path;
      if (path == null) return;
      xfile = XFile(path);
    }

    final conversationId = _conversationId;
    if (conversationId == null) return;

    try {
      final sent = await ApiService.sendFile(
        conversationId,
        xfile,
        replyToId: _replyTo?.id,
      );

      if (mounted) {
        setState(() {
          _upsertMessage(sent);
          _replyTo = null;
        });
      }
    } catch (e) {
      debugPrint('Upload file failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).sendFailed} $e')),
        );
      }
    }
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) return;

    final conversationId = _conversationId;
    if (conversationId == null) return;

    try {
      final sent = await ApiService.sendVideo(
        conversationId,
        video,
        replyToId: _replyTo?.id,
      );

      if (mounted) {
        setState(() {
          _upsertMessage(sent);
          _replyTo = null;
        });
      }
    } catch (e) {
      debugPrint('Upload video failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).sendFailed} $e')),
        );
      }
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
            _upsertMessage(event.message);
          });

          _scrollToBottom();

          // Read receipt: an incoming message appearing while we're in the
          // conversation is read right away, so the peer's "read" ticks and
          // the chat list unread badge update live.
          final id = _conversationId;
          if (id != null && !event.message.isMe) {
            SocketService.instance.markRead(
              conversationId: id,
              peerId: widget.chat.peerId ?? '',
            );
          }
        });
  }

  // ============================================================
  // READ RECEIPTS (two blue ticks)
  // ============================================================

  void _listenForReadReceipts() {
    _readSub =
        SocketService.instance
            .onMessageRead
            .listen((event) {
          if (event.conversationId !=
              _conversationId) {
            return;
          }

          if (!mounted) return;

          setState(() {
            for (final m in event.messages) {
              final idx = _messages.indexWhere(
                (x) => x.id != null && x.id == m.id,
              );
              if (idx != -1) {
                _messages[idx] = _applyReadState(m);
              }
            }
          });
        });
  }

  // ============================================================
  // MESSAGE STATUS HELPERS
  // ============================================================

  /// Users (besides the sender) that can read messages in this chat.
  List<String> _otherParticipantIds() {
    if (widget.chat.isGroup) {
      return widget.chat.members
          .map((m) => m.id.toString())
          .where((id) => id != Session.userId)
          .toList();
    }
    final peerId = widget.chat.peerId;
    return peerId != null && peerId.isNotEmpty ? [peerId] : const [];
  }

  /// Compute the WhatsApp-style status of a server-confirmed message using
  /// the existing readBy semantics (all other participants must have read).
  Message _applyReadState(Message m) {
    if (!m.isMe) return m;
    if (m.id == null || m.status == MessageStatus.pending) return m;

    final others = _otherParticipantIds();
    if (others.isEmpty) return m.copyWith(status: MessageStatus.delivered);

    final readSet = m.readBy.map((e) => e.toString()).toSet();
    final allRead = others.every((id) => readSet.contains(id));
    return m.copyWith(
      status: allRead ? MessageStatus.read : MessageStatus.delivered,
    );
  }

  /// Insert or replace a message, first adopting any local pending
  /// placeholder that shares the same [Message.clientId] (so the server echo
  /// of an online/offline send upgrades one ✓ to two gray ✓✓ instead of
  /// duplicating).
  void _upsertMessage(Message raw) {
    final incoming = _applyReadState(raw);
    upsertIntoList(_messages, incoming, _otherParticipantIds());
  }

  // ============================================================
  // EDITED MESSAGES
  // ============================================================

  void _listenForEditedMessages() {
    _editSub =
        SocketService.instance
            .onMessageEdited
            .listen((event) {
          if (event.conversationId !=
              _conversationId) {
            return;
          }

          if (!mounted) return;

          setState(() {
            _upsertMessage(event.message);
          });
        });
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  void _listenForReactions() {
    _reactionAddSub =
        SocketService.instance
            .onReactionAdded
            .listen((event) {
          _applyReactionEvent(event);
        });

    _reactionRemoveSub =
        SocketService.instance
            .onReactionRemoved
            .listen((event) {
          _applyReactionEvent(event);
        });
  }

  void _applyReactionEvent(ReactionEvent event) {
    if (event.conversationId != _conversationId) return;
    if (!mounted) return;

    setState(() {
      final index = _messages.indexWhere((m) => m.id == event.messageId);
      if (index == -1) return;

      final old = _messages[index];
      final myReactions = event.reactions.entries
          .where((e) => e.value.isReactedBy(Session.userId ?? ''))
          .map((e) => e.key)
          .toList();

      _messages[index] = old.copyWith(
        reactions: event.reactions,
        myReactions: myReactions,
      );
    });
  }

  // ============================================================
  // TYPING
  // ============================================================

  void _listenForTyping() {
    _typingSub =
        SocketService.instance.onTyping.listen((event) {
          if (event.conversationId != _conversationId) return;
          if (event.userId == Session.userId) return;
          if (!mounted) return;

          setState(() {
            _peerTyping = event.typing;
          });
        });
  }

  void _onTypingChanged() {
    final id = _conversationId;
    if (id == null) return;

    SocketService.instance.setTyping(
      conversationId: id,
      peerId: widget.chat.peerId ?? '',
      typing: true,
    );

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      SocketService.instance.setTyping(
        conversationId: id,
        peerId: widget.chat.peerId ?? '',
        typing: false,
      );
    });
  }

  // ============================================================
  // ONLINE / OFFLINE
  // ============================================================

  void _listenForPresence() {
    if (widget.chat.peerId == null) return;

    _presenceSub =
        SocketService.instance.onPresence.listen((event) {
          if (event.userId != widget.chat.peerId) return;
          if (!mounted) return;

          setState(() {
            _peerOnline = event.online;
          });
        });

    // Initial online state from the profile endpoint.
    ApiService.getUserProfile(widget.chat.peerId!)
        .then((profile) {
      if (!mounted) return;
      setState(() {
        _peerOnline = profile.online;
      });
    }).catchError((_) {});
  }

  // ============================================================
  // RECORDING INDICATOR (other users)
  // ============================================================

  void _listenForRecordingIndicator() {
    _recordingStartSub =
        SocketService.instance.onRecordingStarted.listen((event) {
          if (event.conversationId != _conversationId) return;
          if (event.userId == Session.userId) return;
          if (!mounted) return;

          setState(() {
            _peerRecording = true;
          });
        });

    _recordingStopSub =
        SocketService.instance.onRecordingStopped.listen((event) {
          if (event.conversationId != _conversationId) return;
          if (event.userId == Session.userId) return;
          if (!mounted) return;

          setState(() {
            _peerRecording = false;
          });
        });
  }

  // ============================================================
  // PIN EVENTS
  // ============================================================

  void _listenForPins() {
    _pinSub =
        SocketService.instance.onMessagePinned.listen((event) {
          if (event.conversationId != _conversationId) return;
          if (!mounted) return;

          setState(() {
            _pinnedIds
              ..clear()
              ..addAll(event.pinnedMessageIds);
          });
        });

    _unpinSub =
        SocketService.instance.onMessageUnpinned.listen((event) {
          if (event.conversationId != _conversationId) return;
          if (!mounted) return;

          setState(() {
            _pinnedIds
              ..clear()
              ..addAll(event.pinnedMessageIds);
          });
        });
  }

  // ============================================================
  // CALL EVENTS
  // ============================================================

  void _listenForCallEvents() {
    _callAcceptedSub =
        SocketService.instance
            .onCallAccepted
            .listen((event) async {
          debugPrint(
            'CALL ACCEPTED EVENT',
          );

          await JitsiService
              .joinRoom(
            event.roomName,
          );
        });

    _callRejectedSub =
        SocketService.instance
            .onCallRejected
            .listen((_) {
          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content:
              Text(AppLocalizations.of(context).callRejectedLabel),
            ),
          );
        });
  }

  // ============================================================
  // SCROLL
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

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.extentAfter < 80;
    if (atBottom != !_showScrollDownButton) {
      setState(() {
        _showScrollDownButton = !atBottom;
      });
    }
  }

  Future<void> _scrollToMessage(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index == -1) return;

      // Estimate: approximate by item extent ratio.
      final extent = _scrollController.position.maxScrollExtent;
      final ratio = _messages.isEmpty
          ? 0.0
          : index / (_messages.length - 1);
      _scrollController.jumpTo(extent * ratio);

      _flashMessage(index);
    });
  }

  void _flashMessage(int index) {
    // Nothing extra needed; the list will position the message at that index.
  }

  // ============================================================
  // SEND MESSAGE (text)
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

    // Notify the other side that we stopped typing.
    _typingTimer?.cancel();
    SocketService.instance.setTyping(
      conversationId: id,
      peerId: widget.chat.peerId ?? '',
      typing: false,
    );

    final replyId = _replyTo?.id;

    final tempId = _tempId();
    final local = Message(
      id: tempId,
      clientId: tempId,
      text: text,
      isMe: true,
      type: MessageType.text,
      replyToId: replyId,
      replyTo: _replyTo,
      status: MessageStatus.pending,
    );

    if (!SocketService.instance.isConnected) {
      // Offline: show a one-tick pending message and queue for later delivery.
      if (mounted) {
        setState(() => _messages.add(local));
      }
      OfflineQueue.instance.enqueue(PendingMessage(
        id: tempId,
        conversationId: id,
        text: text,
        replyToId: replyId,
        createdAt: DateTime.now(),
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).messagesWillBeSent),
        ),
      );
      widget.chat.lastMessage = text;
      controller.clear();
      if (mounted) {
        setState(() {
          _replyTo = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _messages.add(local));
    }

    _sendViaSocketWithFallback(
      conversationId: id,
      text: text,
      replyToId: replyId,
      clientId: tempId,
    );

    widget.chat.lastMessage =
        text;

    controller.clear();

    if (mounted) {
      setState(() {
        _replyTo = null;
      });
    }
  }

  /// Send the message over the socket and, if the server never confirms it
  /// (rejected ack or timed-out connection), fall back to the REST endpoint
  /// so the text is persisted and survives a reopen. If that also fails the
  /// message enters the persistent offline queue and retries on reconnect.
  Future<void> _sendViaSocketWithFallback({
    required String conversationId,
    required String text,
    String? replyToId,
    required String clientId,
  }) async {
    final completer = Completer<bool>();

    SocketService.instance.sendMessage(
      conversationId: conversationId,
      text: text,
      replyToId: replyToId,
      clientId: clientId,
      onResult: (ok, _) {
        if (completer.isCompleted) return;
        completer.complete(ok);
      },
    );

    bool ok;
    try {
      ok = await completer.future.timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      ok = false;
    }

    if (ok) return;

    try {
      final sent = await ApiService.sendMessage(
        conversationId,
        text: text,
        replyToId: replyToId,
        clientId: clientId,
      );
      if (mounted) {
        setState(() {
          _upsertMessage(sent);
        });
      }
    } catch (e) {
      debugPrint('REST send fallback failed: $e');
      OfflineQueue.instance.enqueue(PendingMessage(
        id: clientId,
        conversationId: conversationId,
        text: text,
        replyToId: replyToId,
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).messagesWillBeSent),
          ),
        );
      }
    }
  }

  String _tempId() =>
      'local_${DateTime.now().microsecondsSinceEpoch}';

  // ============================================================
  // EDIT
  // ============================================================

  void _startEditing(Message message) {
    if (message.type != MessageType.text) return;

    setState(() {
      _editingMessage = message;
      _replyTo = null;
    });

    controller.text = message.text;
    controller.selection =
        TextSelection.collapsed(offset: message.text.length);
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
    });
    controller.clear();
  }

  Future<void> _finishEditing() async {
    final message = _editingMessage;
    final id = _conversationId;

    if (message == null || message.id == null || id == null) return;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    try {
      if (SocketService.instance.isConnected) {
        SocketService.instance.editMessage(
          conversationId: id,
          messageId: message.id!,
          text: text,
        );
      } else {
        await ApiService.editMessage(
          conversationId: id,
          messageId: message.id!,
          text: text,
        );
      }

      if (mounted) {
        setState(() {
          _editingMessage = null;
        });
        controller.clear();
      }
    } catch (e) {
      debugPrint('EDIT ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).sendFailed} $e')),
        );
      }
    }
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  void _toggleReaction(Message message, String emoji) {
    final id = _conversationId;
    if (id == null || message.id == null) return;

    if (emoji.isEmpty) {
      _showReactionPicker(message);
      return;
    }

    final already = message.myReactions.contains(emoji);

    // WhatsApp semantics: one reaction per user per message. Adding a new
    // emoji REPLACES the previous one locally (the server enforces the same),
    // so the bubble updates instantly and the counter per emoji reflects the
    // number of distinct people.
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == message.id);
      if (idx != -1) {
        final m = _messages[idx];
        _messages[idx] = already
            ? m.copyWith(
                myReactions: [...m.myReactions]..remove(emoji),
              )
            : m.copyWith(myReactions: [emoji]);
      }
    });

    if (already) {
      SocketService.instance.removeReaction(
        conversationId: id,
        messageId: message.id!,
        emoji: emoji,
      );
    } else {
      SocketService.instance.addReaction(
        conversationId: id,
        messageId: message.id!,
        emoji: emoji,
      );
    }
  }

  /// WhatsApp picker: ONE reaction per user. Tapping an emoji places it on
  /// the message (replacing any previous one of mine) and closes the sheet.
  void _showReactionPicker(Message message) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogTheme.backgroundColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Live message: local picker state falls back to server truth.
          Message current = message;
          for (final m in _messages) {
            if (m.id == message.id) {
              current = m;
              break;
            }
          }
          final active = current.myReactions.toSet();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _reactionEmojis.map((emoji) {
                  final selected = active.contains(emoji);
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _toggleReaction(current, emoji);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.secondary
                                .withValues(alpha: 0.25)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bottom sheet listing WHO reacted with a given emoji.
  void _showReactionDetails(Message message, String emoji) {
    final theme = Theme.of(context);

    Message current = message;
    for (final m in _messages) {
      if (m.id == message.id) {
        current = m;
        break;
      }
    }

    final summary = current.reactions[emoji];
    if (summary == null || summary.users.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogTheme.backgroundColor,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '$emoji  ${summary.count}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: summary.users.length,
                itemBuilder: (ctx, i) {
                  final u = summary.users[i];
                  final name = (u.name == null || u.name!.isEmpty)
                      ? AppLocalizations.of(context).unknown
                      : u.name!;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.secondary,
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(name),
                    trailing: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORWARD
  // ============================================================

  Future<void> _forwardMessage(Message message) async {
    if (message.id == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardScreen(message: message),
      ),
    );
  }

  // ============================================================
  // PIN / STAR
  // ============================================================

  Future<void> _pinMessage(Message message) async {
    final id = _conversationId;
    if (id == null || message.id == null) return;

    try {
      await ApiService.pinMessage(
        conversationId: id,
        messageId: message.id!,
      );
      if (mounted) {
        setState(() {
          _pinnedIds.add(message.id!);
        });
      }
    } catch (e) {
      debugPrint('PIN ERROR: $e');
    }
  }

  Future<void> _unpinMessage(Message message) async {
    final id = _conversationId;
    if (id == null || message.id == null) return;

    try {
      await ApiService.unpinMessage(
        conversationId: id,
        messageId: message.id!,
      );
      if (mounted) {
        setState(() {
          _pinnedIds.remove(message.id!);
        });
      }
    } catch (e) {
      debugPrint('UNPIN ERROR: $e');
    }
  }

  Future<void> _starMessage(Message message) async {
    final id = _conversationId;
    if (id == null || message.id == null) return;

    try {
      await ApiService.starMessage(
        conversationId: id,
        messageId: message.id!,
      );
      if (mounted) {
        setState(() {
          _starredIds.add(message.id!);
        });
      }
    } catch (e) {
      debugPrint('STAR ERROR: $e');
    }
  }

  Future<void> _unstarMessage(Message message) async {
    final id = _conversationId;
    if (id == null || message.id == null) return;

    try {
      await ApiService.unstarMessage(
        conversationId: id,
        messageId: message.id!,
      );
      if (mounted) {
        setState(() {
          _starredIds.remove(message.id!);
        });
      }
    } catch (e) {
      debugPrint('UNSTAR ERROR: $e');
    }
  }

  bool get _canPin {
    if (!widget.chat.isGroup) return true;
    final admins = widget.chat.admins.map((e) => e.toString()).toList();
    return admins.contains(Session.userId);
  }

  // ============================================================
  // REPLY TO MESSAGE
  // ============================================================

  void _replyToMessage(Message message) {
    setState(() {
      _editingMessage = null;
      _replyTo = ReplyPreview(
        id: message.id,
        text: message.text,
        type: message.type,
        senderName: message.senderName,
        imageUrl: message.imageUrl,
        voiceUrl: message.voiceUrl,
        fileName: message.fileName,
      );
    });
  }

  void _cancelReply() {
    setState(() {
      _replyTo = null;
    });
  }

  // ============================================================
  // TAP REPLY PREVIEW -> scroll to original
  // ============================================================

  Future<void> _tapReply(Message message) async {
    final targetId = message.replyToId;
    if (targetId == null) return;

    final existing = _messages.indexWhere((m) => m.id == targetId);
    if (existing != -1) {
      _scrollToMessage(targetId);
      return;
    }

    // Load context around the original message, then scroll.
    final id = _conversationId;
    if (id == null) return;

    try {
      final messages = await ApiService.getMessageContext(
        conversationId: id,
        messageId: targetId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
      });
      _scrollToMessage(targetId);
    } catch (e) {
      debugPrint('REPLY TAP ERROR: $e');
    }
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

            _pinnedIds.remove(event.messageId);

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
  // SEARCH
  // ============================================================

  Future<void> _runSearch(String query) async {
    final id = _conversationId;
    if (id == null) return;

    setState(() {
      _searchingLoading = true;
    });

    try {
      final results = await ApiService.searchMessages(
        conversationId: id,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searchingLoading = false;
      });
    }
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchResults = [];
        _searchController.clear();
      }
    });
  }

  Future<void> _openSearchResult(Message m) async {
    // Load context around the result and scroll to it.
    final id = _conversationId;
    if (id == null || m.id == null) return;

    try {
      final messages = await ApiService.getMessageContext(
        conversationId: id,
        messageId: m.id!,
      );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchController.clear();
        _searchResults = [];
        _messages
          ..clear()
          ..addAll(messages);
      });
      _scrollToMessage(m.id!);
    } catch (e) {
      debugPrint('SEARCH OPEN ERROR: $e');
    }
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
  // BUILD
  // ============================================================

  String get _appBarSubtitle {
    if (_peerTyping) return 'typing...';
    if (_peerRecording) return 'Recording voice...';
    if (!widget.chat.isGroup && _peerOnline) return 'online';
    if (widget.chat.isGroup) return '${widget.chat.members.length} members';
    return widget.chat.peerId == null ? '' : '';
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    return Scaffold(
      backgroundColor:
      theme.brightness ==
          Brightness.dark
          ? const Color(
        0xFF121212,
      )
          : const Color(
        0xFFECE5DD,
      ),

      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: theme.appBarTheme.foregroundColor,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchMessagesHint,
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (q) {
                  if (q.trim().isEmpty) {
                    setState(() {
                      _searchResults = [];
                    });
                    return;
                  }
                  _runSearch(q.trim());
                },
              )
            : GestureDetector(
                onTap: () {
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

                  if (widget.chat.peerId == null) {
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

                          if (!_searching)
                            Text(
                              _appBarSubtitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: _peerTyping || _peerRecording
                                    ? Colors.white
                                    : Colors.white70,
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

        actions: [
          IconButton(
            color: theme
                .appBarTheme
                .foregroundColor,
            icon: Icon(
              _searching ? Icons.close : Icons.search,
            ),
            onPressed: _toggleSearch,
          ),

          if (_pinnedIds.isNotEmpty)
            IconButton(
              color: theme
                  .appBarTheme
                  .foregroundColor,
              icon: const Icon(
                Icons.push_pin,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PinnedMessagesScreen(
                          chat: widget.chat,
                        ),
                  ),
                );
              },
            ),

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

      body: Container(
        color:
        theme.scaffoldBackgroundColor,

        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _searching
                        ? _buildSearchResults(theme)
                        : _loading
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
                  final message = _messages[index];

                  return MessageBubble(
                    message: message,

                    onDelete:
                        () async {
                      await deleteMessage(
                        index,
                      );
                    },

                    onReply: () =>
                        _replyToMessage(message),

                    onEdit: () =>
                        _startEditing(message),

                    onForward: () =>
                        _forwardMessage(message),

                    onPin: () =>
                        _pinMessage(message),

                    onUnpin: () =>
                        _unpinMessage(message),

                    onStar: () =>
                        _starMessage(message),

                    onUnstar: () =>
                        _unstarMessage(message),

                    onReaction: (emoji) =>
                        _toggleReaction(message, emoji),

                    onReactionDetails: (emoji) =>
                        _showReactionDetails(message, emoji),

                    onTapReply: () =>
                        _tapReply(message),

                    isPinned: message.id != null &&
                        _pinnedIds.contains(message.id),

                    isStarred: message.id != null &&
                        _starredIds.contains(message.id),

                    canPin: _canPin,
                  );
                },
              ),
                  ),
                  if (_showScrollDownButton)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: FloatingActionButton(
                        heroTag: 'scrollDown',
                        mini: true,
                        backgroundColor: theme.colorScheme.secondary,
                        onPressed: () {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ),
                ],
              ),
            ),

            if (_peerRecording)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Recording voice...',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),

            MessageInput(
              controller: controller,

              onSend: sendMessage,

              onPickImage: pickImage,

              onPickFile: pickFile,

              onPickVideo: pickVideo,

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

              reply: _replyTo,

              onCancelReply: _cancelReply,

              isEditing: _editingMessage != null,

              onEditingDone: _finishEditing,

              onCancelEditing: _cancelEditing,

              onTyping: _onTypingChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_searchingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).noSearchResults),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final m = _searchResults[index];
        return ListTile(
          title: Text(
            m.type == MessageType.text
                ? m.text
                : '${m.type.asString} ${AppLocalizations.of(context).messageGeneric}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${m.senderName ?? AppLocalizations.of(context).unknown} · '
            '${m.createdAt.hour.toString().padLeft(2, '0')}:'
            '${m.createdAt.minute.toString().padLeft(2, '0')}',
          ),
          onTap: () => _openSearchResult(m),
        );
      },
    );
  }
}
