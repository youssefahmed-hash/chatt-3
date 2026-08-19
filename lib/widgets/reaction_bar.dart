import 'package:flutter/material.dart';
import '../models/message.dart';

/// Emoji reaction bar shown under a message.
///
/// WhatsApp-style compact bar: existing reactions render as small emoji pills
/// followed by an add-reaction [+] pill. The bar is kept small so it never
/// forces the message bubble wider than its text content.
class ReactionBar extends StatelessWidget {
  final Map<String, ReactionSummary> reactions;
  final List<String> myReactions;
  final List<String> emojis;
  final ValueChanged<String> onTap;

  /// Long-press a reaction pill to see WHO reacted with it.
  final ValueChanged<String>? onLongTap;

  /// Fallback quick reactions offered when no list is provided, so adding a
  /// first reaction is still possible via the [+] pill.
  static const _defaultEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.myReactions,
    required this.emojis,
    required this.onTap,
    this.onLongTap,
  });

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries
        .where((e) => e.value.count > 0)
        .toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    final quickEmojis = emojis.isNotEmpty ? emojis : _defaultEmojis;

    // Nothing to offer: no reactions yet and no quick reactions configured.
    if (entries.isEmpty && quickEmojis.isEmpty) return const SizedBox.shrink();

    // Kept compact (max 200 wide, wraps to a second line) so the bar never
    // widens the message bubble beyond its text like WhatsApp.
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              ...entries.map(
                (e) => _pill(
                  context,
                  label: '${e.key} ${e.value.count}',
                  reacted: myReactions.contains(e.key),
                  onTap: () => onTap(e.key),
                  onLongTap: onLongTap == null
                      ? null
                      : () => onLongTap!(e.key),
                ),
              ),
              // Add-reaction pill: offers a first reaction on fresh messages.
              _pill(
                context,
                icon: Icons.add_reaction_outlined,
                onTap: () => onTap(''),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    String? label,
    IconData? icon,
    bool reacted = false,
    required VoidCallback onTap,
    VoidCallback? onLongTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? 8 : 6,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: reacted
              ? colors.secondary.withValues(alpha: 0.25)
              : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: reacted
                ? colors.secondary
                : label != null
                    ? Colors.transparent
                    : Colors.grey.shade400,
          ),
        ),
        child: label != null
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Icon(icon, size: 15),
      ),
    );
  }
}
