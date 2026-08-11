import 'package:flutter/material.dart';

class ChatTextField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const ChatTextField({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      style: TextStyle(
        color: theme.textTheme.bodyLarge?.color,
      ),
      decoration: InputDecoration(
        hintText: "Type a message...",
        hintStyle: TextStyle(
          color: theme.hintColor,
        ),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF2F2F2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: theme.colorScheme.secondary,
            width: 2,
          ),
        ),
      ),
      onSubmitted: (_) => onSend(),
    );
  }
}