import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'chat_screen.dart';

/// Archived conversations (per-user).
class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  List<Chat> _chats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final chats = await ApiService.getArchivedConversations();
      if (!mounted) return;
      setState(() {
        _chats = chats;
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

  Future<void> _unarchive(Chat chat) async {
    if (chat.id == null) return;
    try {
      await ApiService.unarchiveConversation(chat.id!);
      setState(() {
        _chats.removeWhere((c) => c.id == chat.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unarchive: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).archivedChats),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Could not load:\n$_error'))
          : _chats.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).noArchivedChats))
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondary,
                    backgroundImage:
                        chat.groupImage != null &&
                            chat.groupImage!.isNotEmpty
                            ? NetworkImage(
                                '${ApiConfig.baseUrl}${chat.groupImage}')
                            : null,
                    child: chat.groupImage == null ||
                            chat.groupImage!.isEmpty
                        ? Text(chat.name.isNotEmpty
                            ? chat.name[0]
                            : '?')
                        : null,
                  ),
                  title: Text(chat.name),
                  subtitle: Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    chat.time,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(chat: chat),
                      ),
                    );
                  },
                  onLongPress: () => _unarchive(chat),
                );
              },
            ),
    );
  }
}
