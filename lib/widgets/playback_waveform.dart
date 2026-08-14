import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight waveform visualization for already-sent voice messages.
///
/// Bars are generated deterministically from [seed] (e.g. the message id) and
/// the message [duration], so the same message always renders the same
/// waveform without loading the audio file into memory.
///
/// The waveform is draggable / tappable to seek: [onSeekFraction] receives a
/// 0..1 fraction of the total duration.
class PlaybackWaveform extends StatelessWidget {
  /// Total duration in milliseconds (used to derive the bar count).
  final int durationMs;

  /// Current playback position in milliseconds.
  final int positionMs;

  /// Stable seed (e.g. message id hash) so the bars don't change per build.
  final int seed;

  /// Called when the user taps/drags at a [fraction] of the total duration.
  final ValueChanged<double>? onSeekFraction;

  /// Played-bar color (uses [Theme] primary when null).
  final Color? playedColor;

  /// Remaining-bar color.
  final Color? restColor;

  const PlaybackWaveform({
    super.key,
    required this.durationMs,
    required this.positionMs,
    required this.seed,
    this.onSeekFraction,
    this.playedColor,
    this.restColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final played = playedColor ?? theme.colorScheme.secondary;
    final rest = restColor ?? theme.dividerColor;

    final total = math.max(durationMs, 1);
    final fraction =
        (positionMs / total).clamp(0.0, 1.0).toDouble();

    // Between 24 and 40 bars depending on duration.
    final barCount = (20 + (total / 500).floor()).clamp(24, 40);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final slot = width / barCount;
        final barWidth = (slot * 0.5).clamp(1.5, 4.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            onSeekFraction?.call(
              (d.localPosition.dx / width).clamp(0.0, 1.0),
            );
          },
          onHorizontalDragUpdate: (d) {
            onSeekFraction?.call(
              (d.localPosition.dx / width).clamp(0.0, 1.0),
            );
          },
          child: SizedBox(
            height: 34,
            width: width,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(
                    barCount,
                    (i) {
                      final value = _barValue(i, barCount);
                      final isPlayed = (i / barCount) <= fraction;
                      return Container(
                        width: barWidth,
                        height: 6 + (value * 24),
                        decoration: BoxDecoration(
                          color: isPlayed ? played : rest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
                // Progress indicator.
                Positioned(
                  left: width * fraction - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: played,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Deterministic pseudo-random bar height (0..1) from seed + index.
  double _barValue(int index, int count) {
    final h = (seed ^ (index * 2654435761) ^ (count * 40503)) & 0xffff;
    final v = (h % 100) / 100.0;
    // Bias towards a speech-like distribution (more mid, some peaks).
    return (0.25 + v * 0.75);
  }
}
