import 'dart:async';
import 'package:flutter/material.dart';
import 'select_group_members_screen.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../services/socket_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import '../config/api_config.dart';
import 'settings_screen.dart';
import './profile_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController searchController = TextEditingController();

  List<Chat> _chats = [];
  List<Chat> _filtered = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<NewMessageEvent>? _msgSub;
  StreamSubscription<GroupAddedEvent>? _groupSub;
  StreamSubscription<GroupUpdatedEvent>? _groupUpdatedSub;
  @override
  void initState() {
    super.initState();
    _loadConversations();
    // When any new message arrives, refresh previews/ordering.
    _msgSub = SocketService.instance.onNewMessage.listen((_) {
      _loadConversations();
    });

    _groupSub = SocketService.instance.onGroupAdded.listen((event) {
          final chat = Chat.fromJson(event.conversation);

          setState(() {
            _chats.removeWhere((c) => c.id == chat.id);

            _chats.insert(0, chat);

            _applySearch(searchController.text);
          });
    });
    _groupUpdatedSub =
        SocketService.instance.onGroupUpdated.listen((event) {

          final index = _chats.indexWhere(
                (c) => c.id == event.conversationId,
          );

          if (index == -1) return;

          setState(() {

            _chats[index].name = event.groupName;

            if (event.groupImage != null) {
              _chats[index].groupImage = event.groupImage;
            }

            _applySearch(searchController.text);

          });

        });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _groupSub?.cancel();
    _groupUpdatedSub?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final chats = await ApiService.getConversations();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _error = null;
        _loading = false;
      });
      _applySearch(searchController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applySearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _chats;
      } else {
        _filtered = _chats
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _logout() async {
    SocketService.instance.disconnect();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// Bottom sheet to pick a user and start a new conversation.
  Future<void> _startNewChat() async {
    List<Map<String, dynamic>> users = [];
    try {
      users = await ApiService.listUsers();
    } catch (e) {
      _showSnack(e.toString());
      return;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Start a new chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No other users yet. Register another account.'),
            ),
          ...users.map((u) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary,                  child: Text((u['name'] ?? '?')[0].toString()),
                ),
                title: Text(u['name'] ?? ''),
                subtitle: Text(u['email'] ?? ''),
                onTap: () async {
                  Navigator.pop(context);
                  await _openConversationWith(u['id'].toString());
                },
              )),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final Chat? group = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectGroupMembersScreen(),
      ),
    );

    if (group == null) return;

    setState(() {
      _chats.insert(0, group);
      _filtered = List.from(_chats);
    });

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chat: group),
      ),
    );
  }

  Future<void> _openConversationWith(String userId) async {
    try {
      final chat = await ApiService.startConversation(userId);

      print('selected userId = $userId');
      print('chat.id = ${chat.id}');
      print('chat.peerId = ${chat.peerId}');
      print('chat.name = ${chat.name}');
      await _loadConversations();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
      );
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Session.userName == null ? 'Chats' : 'Chats · ${Session.userName}'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [

          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            FloatingActionButton(
              heroTag: "group",
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: _createGroup,
              child: const Icon(Icons.group),
            ),

            const SizedBox(height: 12),

            FloatingActionButton(
              heroTag: "chat",
              backgroundColor: Theme.of(context).colorScheme.secondary,
              onPressed: _startNewChat,
              child: const Icon(Icons.chat),
            ),
          ],
        ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ===== SEARCH BAR =====
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: searchController,
              onChanged: _applySearch,
              decoration: InputDecoration(
                hintText: "Search chats...",
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).iconTheme.color,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ===== CHAT LIST =====
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load chats:\n$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('No chats yet. Tap the button to start one.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          final chat = _filtered[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              backgroundImage: chat.groupImage != null &&
                  chat.groupImage!.isNotEmpty
                  ? NetworkImage(
                "${ApiConfig.baseUrl}${chat.groupImage}",
              )
                  : null,

              child: chat.groupImage == null ||
                  chat.groupImage!.isEmpty
                  ? Text(
                chat.name.isNotEmpty ? chat.name[0] : '?',
              )
                  : null,
            ),
            title: Text(chat.name),
            subtitle: Text(
              chat.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(chat.time, style: const TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
              ).then((_) => _loadConversations());
            },
          );
        },
      ),
    );
  }
}
