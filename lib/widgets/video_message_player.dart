import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/api_config.dart';
import '../screens/full_screen_video.dart';

/// Video message with thumbnail preview and inline playback.
class VideoMessagePlayer extends StatefulWidget {
  final String url;
  final String? thumbUrl;

  const VideoMessagePlayer({
    super.key,
    required this.url,
    this.thumbUrl,
  });

  @override
  State<VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<VideoMessagePlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;

  String _fullUrl(String path) =>
      path.startsWith('http') ? path : '${ApiConfig.baseUrl}$path';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_fullUrl(widget.url)),
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        if (c.value.position >= c.value.duration &&
            c.value.duration != Duration.zero) {
          c.seekTo(Duration.zero);
        }
        c.play();
      }
    });
  }

  /// Open the enlarged/fullscreen viewer reusing the same streamed URL.
  void _openFullscreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideo(
          url: _fullUrl(widget.url),
          thumbUrl: widget.thumbUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_error) {
      return GestureDetector(
        onTap: _openFullscreen,
        child: Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF262D31)
                : Colors.black12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text('Video could not be loaded'),
          ),
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return GestureDetector(
        onTap: _openFullscreen,
        child: Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF262D31)
                : Colors.black12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final controller = _controller!;
    final playing = controller.value.isPlaying;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          SizedBox(
            width: 220,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          // Full-size overlay: the platform video view swallows pointer
          // events on web, so a plain GestureDetector around the player never
          // fires. Cover it with an invisible tap layer to open the fullscreen
          // viewer on tap, like WhatsApp.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openFullscreen,
            ),
          ),
          Positioned(
            left: 6,
            bottom: 4,
            child: GestureDetector(
              // Small inline play/pause control; tapping anywhere else on the
              // video opens the fullscreen view.
              onTap: _togglePlay,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 26,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 6,
            child: IgnorePointer(
              child: Text(
                '${_formatDuration(controller.value.position)} / '
                '${_formatDuration(controller.value.duration)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
