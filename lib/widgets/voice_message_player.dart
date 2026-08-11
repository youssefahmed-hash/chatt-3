import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final int duration;

  const VoiceMessagePlayer({
    super.key,
    required this.url,
    required this.duration,
  });

  @override
  State<VoiceMessagePlayer> createState() =>
      _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState
    extends State<VoiceMessagePlayer> {

  final AudioPlayer player = AudioPlayer();

  bool playing = false;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    player.onPlayerComplete.listen((_) {
      if (!mounted) return;

      setState(() {
        playing = false;
        position = Duration.zero;
      });

      player.seek(Duration.zero);
    });

    player.onPositionChanged.listen((p) {
      if (!mounted) return;

      setState(() {
        position = p;
      });
    });

    player.onDurationChanged.listen((d) {
      if (!mounted) return;

      setState(() {
        duration = d;
      });
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> play() async {

    if (playing) {

      await player.pause();

      setState(() {
        playing = false;
      });

      return;
    }

    await player.play(
      UrlSource(widget.url),
    );

    setState(() {
      playing = true;
    });
  }

  String format(Duration d) {

    final m =
    d.inMinutes.toString().padLeft(2, '0');

    final s =
    (d.inSeconds % 60)
        .toString()
        .padLeft(2, '0');

    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {

    final total =
    duration == Duration.zero
        ? Duration(
      seconds: widget.duration,
    )
        : duration;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: play,
            icon: Icon(
              playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              size: 38,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 130,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                ),
                overlayShape:
                SliderComponentShape.noOverlay,
              ),
              child: Slider(
                min: 0,
                max: total.inMilliseconds == 0
                    ? 1
                    : total.inMilliseconds.toDouble(),
                value: position.inMilliseconds
                    .clamp(
                  0,
                  total.inMilliseconds == 0
                      ? 1
                      : total.inMilliseconds,
                )
                    .toDouble(),
                onChanged: (value) async {

                  await player.seek(
                    Duration(
                      milliseconds:
                      value.toInt(),
                    ),
                  );

                  setState(() {
                    position = Duration(
                      milliseconds:
                      value.toInt(),
                    );
                  });
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            "${format(position)} / ${format(total)}",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

        ],
      ),
    );
  }
}