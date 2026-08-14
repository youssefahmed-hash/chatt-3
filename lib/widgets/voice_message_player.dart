import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'playback_waveform.dart';

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
  bool loading = false;
  bool failed = false;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  double _speed = 1.0;

  int get _seed => widget.url.hashCode ^ widget.duration;

  @override
  void initState() {
    super.initState();

    player.onPlayerComplete.listen((_) {
      if (!mounted) return;

      setState(() {
        playing = false;
        loading = false;
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

    player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      if (state == PlayerState.completed) {
        setState(() {
          playing = false;
          loading = false;
          position = Duration.zero;
        });
        player.seek(Duration.zero);
      } else if (state == PlayerState.playing) {
        setState(() {
          loading = false;
          failed = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      player.stop();
      if (mounted) {
        setState(() {
          playing = false;
          loading = false;
          failed = false;
          position = Duration.zero;
          duration = Duration.zero;
          _speed = 1.0;
        });
      }
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> play() async {
    if (playing) {
      await player.pause();
      if (!mounted) return;
      setState(() {
        playing = false;
      });
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
      failed = false;
    });

    try {
      if (position == Duration.zero && duration == Duration.zero) {
        await player.play(UrlSource(widget.url));
      } else {
        await player.resume();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        failed = true;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      playing = true;
      loading = false;
    });
  }

  /// Cycle playback speed: 1x -> 1.5x -> 2x -> 1x
  Future<void> cycleSpeed() async {
    final next = _speed >= 2.0 ? 1.0 : _speed + 0.5;

    try {
      await player.setPlaybackRate(next);
    } catch (_) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _speed = next;
    });
  }

  /// Seek to a fraction (0..1) of the total duration.
  Future<void> seekToFraction(double fraction) async {
    if (failed) return;

    final total = duration == Duration.zero
        ? Duration(seconds: widget.duration)
        : duration;

    final target = Duration(
      milliseconds: (total.inMilliseconds * fraction).toInt(),
    );

    try {
      await player.seek(target);
    } catch (_) {
      return;
    }

    if (!mounted) return;

    setState(() {
      position = target;
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
            onPressed: failed ? play : (loading ? null : play),
            icon: Icon(
              failed
                  ? Icons.refresh
                  : loading
                  ? Icons.hourglass_empty
                  : playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              size: 38,
              color: failed
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),

          const SizedBox(width: 8),

          // Playback waveform (tap/drag to seek).
          SizedBox(
            width: 130,
            child: PlaybackWaveform(
              durationMs: total.inMilliseconds,
              positionMs: position.inMilliseconds,
              seed: _seed,
              onSeekFraction: seekToFraction,
            ),
          ),

          const SizedBox(width: 8),

          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${format(position)} / ${format(total)}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Playback speed toggle.
              GestureDetector(
                onTap: cycleSpeed,
                child: Text(
                  '${_speed.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF25D366),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
