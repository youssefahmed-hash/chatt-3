import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import '../services/api_service.dart';
import '../services/session.dart';

/// Per-user starred messages view.
class StarredMessagesScreen extends StatefulWidget {
  const StarredMessagesScreen({super.key});

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  List<Message> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await ApiService.getStarredMessages();
      final myId = Session.userId ?? '';
      final messages = raw
          .map((e) => Message.fromJson(e, myId))
          .where((m) => m.id != null)
          .toList();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).starredMessages),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Could not load:\n$_error'))
          : _messages.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).noStarredMessages))
          : ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return ListTile(
                  leading: const Icon(Icons.star, color: Color(0xFF25D366)),
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
