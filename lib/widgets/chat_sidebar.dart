import 'package:flutter/material.dart';
import '../models/chat.dart';

class ChatSidebar extends StatelessWidget {
  final List<Chat> chats;
  final int? selectedChat;
  final Function(int) onSelect;

  const ChatSidebar({
    super.key,
    required this.chats,
    required this.selectedChat,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];

        return ListTile(
          selected: selectedChat == index,
          leading: CircleAvatar(
            child: Text(chat.name[0]),
          ),
          title: Text(chat.name),
          subtitle: Text(chat.lastMessage),
          trailing: Text(chat.time),
          onTap: () => onSelect(index),
        );
      },
    );
  }
}