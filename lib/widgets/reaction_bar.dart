import 'package:flutter/material.dart';
import '../models/message.dart';

/// Emoji reaction bar shown under a message.
class ReactionBar extends StatelessWidget {
  final Map<String, ReactionSummary> reactions;
  final List<String> myReactions;
  final List<String> emojis;
  final ValueChanged<String> onTap;

  /// Fallback quick reactions shown when no list is provided, so a message
  /// without reactions still offers an affordance to react.
  static const _defaultEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.myReactions,
    required this.emojis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries
        .where((e) => e.value.count > 0)
        .toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    final quickEmojis = emojis.isNotEmpty ? emojis : _defaultEmojis;

    // Nothing to show: no reactions yet and no quick reactions configured.
    if (entries.isEmpty && quickEmojis.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            if (entries.isNotEmpty) ...[
              ...entries.map((e) {
                final reacted = myReactions.contains(e.key);
                return GestureDetector(
                  onTap: () => onTap(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: reacted
                          ? Theme.of(context).colorScheme.secondary
                              .withValues(alpha: 0.25)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: reacted
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '${e.key} ${e.value.count}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                );
              }),
              // Quick-reaction button.
              GestureDetector(
                onTap: () => onTap(''),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Icon(Icons.add_reaction_outlined, size: 15),
                ),
              ),
            ] else
              ...quickEmojis.map((emoji) {
                final reacted = myReactions.contains(emoji);
                return GestureDetector(
                  onTap: () => onTap(emoji),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: reacted
                          ? Theme.of(context).colorScheme.secondary
                              .withValues(alpha: 0.25)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: reacted
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 13)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
