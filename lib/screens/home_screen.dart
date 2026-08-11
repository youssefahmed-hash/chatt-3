import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import '../data/sample_chats.dart';
import '../widgets/chat_header.dart';
import '../widgets/message_bubble.dart';
// import '../widgets/message_input.dart';
import '../services/meet_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? selectedChat;

  final TextEditingController messageController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  List<Chat> chats = sampleChats;
  List<Chat> filteredChats = sampleChats;

  // ================= ANDROID STYLE COLORS =================
  Color sidebarColor() => const Color(0xFFF1F3F4); // Android light grey

  Color selectedTileColor() => const Color(0xFFD2E3FC); // Google blue soft

  // ================= SEARCH =================
  void searchChats(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredChats = chats;
      } else {
        filteredChats = chats
            .where((c) =>
            c.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // ================= MESSAGE =================
  void sendTextMessage() {
    if (selectedChat == null) return;

    final text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      chats[selectedChat!].messages.add(
        Message(text: text, isMe: true),
      );

      chats[selectedChat!].lastMessage = text;
      chats[selectedChat!].time = "now";
    });

    messageController.clear();
  }

  // ================= VIDEO CALL =================
  void sendVideoCall() {
    if (selectedChat == null) return;

    const url = "https://meet.google.com/new";

    setState(() {
      chats[selectedChat!].messages.add(
        Message(
          text: "Video Call",
          isMe: true,
          type: MessageType.videoCall,
          callUrl: url,
        ),
      );
    });

    MeetService.openNewMeeting();
  }

  // ================= VOICE CALL =================
  void sendVoiceCall() {
    if (selectedChat == null) return;

    const url = "https://meet.google.com/new";

    setState(() {
      chats[selectedChat!].messages.add(
        Message(
          text: "Voice Call",
          isMe: true,
          type: MessageType.voiceCall,
          callUrl: url,
        ),
      );
    });

    MeetService.openNewMeeting();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Row(
          children: [
            // ================= SIDEBAR (ANDROID STYLE) =================
            Container(
              width: 320,
              decoration: BoxDecoration(
                color: sidebarColor(),
                border: const Border(
                  right: BorderSide(
                    color: Color(0xFFE0E0E0),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // ===== SEARCH BAR =====
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: searchController,
                      onChanged: searchChats,
                      decoration: InputDecoration(
                        hintText: "Search chats",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // ===== CHAT LIST =====
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredChats.length,
                      itemBuilder: (context, index) {
                        final chat = filteredChats[index];

                        final isSelected =
                            selectedChat != null &&
                                chats[selectedChat!] == chat;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedTileColor()
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1A73E8),
                              child: Text(
                                chat.name[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            title: Text(
                              chat.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            subtitle: Text(
                              chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            onTap: () {
                              setState(() {
                                selectedChat = chats.indexOf(chat);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ================= CHAT AREA =================
            Expanded(
              child: selectedChat == null
                  ? const Center(
                child: Text(
                  "Select a chat",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              )
                  : Column(
                children: [
                  // ===== HEADER =====
                  ChatHeader(
                    name: chats[selectedChat!].name,
                    onVideoCall: sendVideoCall,
                    onVoiceCall: sendVoiceCall,
                  ),

                  // ===== MESSAGES =====
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount:
                      chats[selectedChat!].messages.length,
                      itemBuilder: (context, index) {
                        return MessageBubble(
                          message: chats[selectedChat!]
                              .messages[index],
                        );
                      },
                    ),
                  ),

                  // ===== INPUT =====
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFFE0E0E0),
                        ),
                      ),
                    ),
                    // child: MessageInput(
                    //   controller: messageController,
                    //   onSend: sendTextMessage,
                    // ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}