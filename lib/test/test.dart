import 'package:flutter/material.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ================= MESSAGE MODEL =================
class Message {
  final String text;
  final bool isMe;

  Message({
    required this.text,
    required this.isMe,
  });
}

// ================= CHAT MODEL =================
class Chat {
  final String name;
  String lastMessage;
  String time;
  final List<Message> messages;

  Chat({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.messages,
  });
}

// ================= HOME SCREEN =================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? selectedChat;

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<Chat> chats = [
    Chat(name: "Ahmed", lastMessage: "Hey!", time: "10:30", messages: []),
    Chat(name: "Sara", lastMessage: "See you", time: "09:15", messages: []),
    Chat(name: "Mohamed", lastMessage: "Project ready", time: "Yesterday", messages: []),
    Chat(name: "Omar", lastMessage: "Let's meet", time: "Monday", messages: []),
  ];

  void sendMessage() {
    if (selectedChat == null) return;

    final text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      final chat = chats[selectedChat!];

      chat.messages.add(
        Message(text: text, isMe: true),
      );

      chat.lastMessage = text;
      chat.time = "now";
    });

    messageController.clear();

    Future.delayed(const Duration(milliseconds: 50), () {
      if (scrollController.hasClients) {
        scrollController.jumpTo(
          scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          return isDesktop ? desktopLayout() : mobileLayout();
        },
      ),
    );
  }

  // ================= DESKTOP =================
  Widget desktopLayout() {
    return Row(
      children: [
        buildSidebar(),
        Expanded(child: buildChatArea()),
      ],
    );
  }

  // ================= MOBILE =================
  Widget mobileLayout() {
    return selectedChat == null
        ? buildSidebar(isMobile: true)
        : buildChatArea(isMobile: true);
  }

  // ================= SIDEBAR =================
  Widget buildSidebar({bool isMobile = false}) {
    return Container(
      width: isMobile ? double.infinity : 350,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 70,
            color: const Color(0xFFE3F2FD),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF1976D2),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                Spacer(),
                Icon(Icons.chat, color: Color(0xFF1976D2)),
                SizedBox(width: 12),
                Icon(Icons.more_vert, color: Color(0xFF1976D2)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search chats...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1976D2)),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];

                return ListTile(
                  selected: selectedChat == index,
                  selectedTileColor: const Color(0xFFE3F2FD),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1976D2),
                    child: Text(
                      chat.name[0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(chat.name),
                  subtitle: Text(chat.lastMessage),
                  trailing: Text(
                    chat.time,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      selectedChat = index;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= CHAT AREA =================
  Widget buildChatArea({bool isMobile = false}) {
    if (selectedChat == null) {
      return const Center(
        child: Text(
          "Select a chat",
          style: TextStyle(fontSize: 22, color: Colors.black54),
        ),
      );
    }

    final chat = chats[selectedChat!];

    return Column(
      children: [
        // HEADER
        Container(
          height: 70,
          color: const Color(0xFFE3F2FD),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      selectedChat = null;
                    });
                  },
                ),

              CircleAvatar(
                backgroundColor: const Color(0xFF1976D2),
                child: Text(chat.name[0]),
              ),

              const SizedBox(width: 10),
              Text(
                chat.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // MESSAGES
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chat.messages.length,
              itemBuilder: (context, index) {
                final msg = chat.messages[index];

                return Align(
                  alignment:
                  msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isMe
                          ? const Color(0xFF1976D2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isMe ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // INPUT
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  onSubmitted: (_) => sendMessage(),
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: const Color(0xFF1976D2),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}