import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

/// Pinned messages view for a conversation.
class PinnedMessagesScreen extends StatefulWidget {
  final Chat chat;

  const PinnedMessagesScreen({super.key, required this.chat});

  @override
  State<PinnedMessagesScreen> createState() => _PinnedMessagesScreenState();
}

class _PinnedMessagesScreenState extends State<PinnedMessagesScreen> {
  List<Message> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.chat.id == null) return;
    try {
      final messages =
          await ApiService.getPinnedMessages(widget.chat.id!);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openMessage(Message m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chat: widget.chat,
          highlightMessageId: m.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).pinnedMessages),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Could not load:\n$_error'))
          : _messages.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).noPinnedMessages))
          : ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return ListTile(
                  leading: const Icon(
                    Icons.push_pin,
                    color: Color(0xFF25D366),
                  ),
                  title: Text(
                    m.type == MessageType.text
                        ? m.text
                        : _typeLabel(m.type),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${m.senderName ?? AppLocalizations.of(context).unknown} · ${_formatTime(m.createdAt)}',
                  ),
                  isThreeLine: true,
                  onTap: () => _openMessage(m),
                );
              },
            ),
    );
  }

  String _typeLabel(MessageType t) {
    final l10n = AppLocalizations.of(context);
    switch (t) {
      case MessageType.image:
        return l10n.photoNotification;
      case MessageType.voice:
        return l10n.voiceNotification;
      case MessageType.file:
        return l10n.fileNotification;
      case MessageType.video:
        return l10n.videoNotification;
      case MessageType.videoCall:
        return l10n.videoCallNotification;
      case MessageType.voiceCall:
        return l10n.voiceCallNotification;
      default:
        return l10n.messageGeneric;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
