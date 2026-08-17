import 'package:flutter/material.dart';

class VoiceRecorderBar extends StatelessWidget {
  final String time;

  final List<double> waveform;

  final bool isPaused;

  final VoidCallback onPause;
  final VoidCallback onResume;

  final VoidCallback onCancel;

  final VoidCallback onSend;

  const VoiceRecorderBar({
    super.key,
    required this.time,
    required this.waveform,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final secondary =
        theme.colorScheme.secondary;

    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      height: 76,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
      ),

      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF252525)
            : Colors.white,

        borderRadius:
        BorderRadius.circular(24),
      ),

      child: Column(
        children: [
          // ========================================================
          // TOP
          // ========================================================

          Expanded(
            child: Row(
              children: [
                // ==================================================
                // PAUSE / RESUME
                // ==================================================

                GestureDetector(
                  onTap: isPaused
                      ? onResume
                      : onPause,

                  child: Container(
                    width: 38,
                    height: 38,

                    decoration:
                    BoxDecoration(
                      color: secondary,
                      shape:
                      BoxShape.circle,
                    ),

                    child: Icon(
                      isPaused
                          ? Icons.play_arrow
                          : Icons.pause,

                      color: Colors.white,

                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                // ==================================================
                // WAVEFORM
                // ==================================================

                Expanded(
                  child: ClipRect(
                    child: Align(
                      alignment:
                      Alignment.centerRight,

                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.end,

                        crossAxisAlignment:
                        CrossAxisAlignment.center,

                        children:
                        _buildWaveform(
                          secondary,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                // ==================================================
                // TIME
                // ==================================================

                Text(
                  time,

                  style: TextStyle(
                    color: theme
                        .textTheme
                        .bodyLarge
                        ?.color,

                    fontSize: 13,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ========================================================
          // BOTTOM
          // ========================================================

          SizedBox(
            height: 30,

            child: Row(
              children: [
                // ==================================================
                // DELETE
                // ==================================================

                Expanded(
                  child: Align(
                    alignment:
                    Alignment.centerLeft,

                    child:
                    GestureDetector(
                      onTap: onCancel,

                      child: const Icon(
                        Icons
                            .delete_outline,

                        size: 20,

                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // RECORDING TEXT
                // ==================================================

                Expanded(
                  flex: 3,

                  child: Center(
                    child: Text(
                      isPaused
                          ? 'Paused'
                          : 'Recording...',

                      style: const TextStyle(
                        color: Colors.grey,

                        fontSize: 11,
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // SEND
                // ==================================================

                Expanded(
                  child: Align(
                    alignment:
                    Alignment.centerRight,

                    child:
                    GestureDetector(
                      onTap: onSend,

                      child: Container(
                        width: 34,
                        height: 34,

                        decoration:
                        BoxDecoration(
                          color: secondary,
                          shape:
                          BoxShape.circle,
                        ),

                        child:
                        const Icon(
                          Icons.send,

                          color:
                          Colors.white,

                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WAVEFORM
  // ============================================================

  List<Widget> _buildWaveform(
      Color color,
      ) {
    if (waveform.isEmpty) {
      return List.generate(
        35,
            (index) {
          return Container(
            width: 2,

            height: 6,

            margin:
            const EdgeInsets
                .symmetric(
              horizontal: 1,
            ),

            decoration:
            BoxDecoration(
              color:
              color.withValues(alpha: .25),

              borderRadius:
              BorderRadius.circular(
                3,
              ),
            ),
          );
        },
      );
    }

    return waveform.map(
          (value) {
        final height =
            5 + (value * 22);

        return Container(
          width: 2,

          height: height,

          margin:
          const EdgeInsets.symmetric(
            horizontal: 1,
          ),

          decoration:
          BoxDecoration(
            color: color,

            borderRadius:
            BorderRadius.circular(
              3,
            ),
          ),
        );
      },
    ).toList();
  }
}