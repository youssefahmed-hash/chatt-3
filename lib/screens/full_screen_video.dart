import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/api_config.dart';
import '../l10n/generated/app_localizations.dart';

/// Fullscreen video viewer opened when the user taps a video message.
///
/// Uses the SAME `video_player` network streaming as the inline bubble (so the
/// upload/playback stack is untouched), preserves aspect ratio, offers
/// play/pause + position, a clear close/back action, and degrades gracefully
/// if the URL cannot be loaded.
class FullScreenVideo extends StatefulWidget {
  final String url;
  final String? thumbUrl;

  const FullScreenVideo({
    super.key,
    required this.url,
    this.thumbUrl,
  });

  @override
  State<FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<FullScreenVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
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
      await controller.play();
      if (!mounted) return;
      setState(() {
        _ready = true;
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: _error
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppLocalizations.of(context).videoCouldNotLoad,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                )
              : !_ready || _controller == null
                  ? const CircularProgressIndicator()
                  : _buildPlayer(_controller!),
        ),
      ),
    );
  }

  Widget _buildPlayer(VideoPlayerController controller) {
    final playing = controller.value.isPlaying;
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          Icon(
            playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            size: 56,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_formatDuration(controller.value.position)} / '
                '${_formatDuration(controller.value.duration)}',
                style: const TextStyle(
                  fontSize: 12,
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
}