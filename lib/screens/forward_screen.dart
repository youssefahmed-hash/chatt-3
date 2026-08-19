import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

/// Picks a target conversation to forward [message] to.
class ForwardScreen extends StatefulWidget {
  final Message message;

  const ForwardScreen({super.key, required this.message});

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  List<Chat> _chats = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final chats = await ApiService.getConversations();
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

  Future<void> _forward(Chat chat) async {
    if (chat.id == null) return;

    setState(() {
      _sending = true;
    });

    try {
      await ApiService.forwardMessage(
        targetConversationId: chat.id!,
        messageId: widget.message.id!,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forward failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forward to...'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      '${AppLocalizations.of(context).couldNotLoadChats}:\n$_error',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            )
          : _chats.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).noConversationsYet))
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
                  onTap: () => _forward(chat),
                );
              },
            ),
      bottomNavigationBar: _sending
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            )
          : null,
    );
  }
}
