import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  final String name;
  final VoidCallback onVideoCall;
  final VoidCallback onVoiceCall;

  const ChatHeader({
    super.key,
    required this.name,
    required this.onVideoCall,
    required this.onVoiceCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      color: const Color(0xFF1976D2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const Spacer(),

          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: onVoiceCall,
          ),

          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: onVideoCall,
          ),
        ],
      ),
    );
  }
}