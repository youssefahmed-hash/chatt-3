import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/file_download.dart';

/// Fullscreen image viewer opened when the user taps an image message.
/// Supports pinch/zoom and downloading the image to the device (same
/// download flow as files).
class FullScreenImage extends StatefulWidget {
  final String imageUrl;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  bool _downloading = false;

  Future<void> _download(BuildContext context) async {
    if (_downloading) return;
    final l10n = AppLocalizations.of(context);
    final fileName =
        widget.imageUrl.split('/').last.split('?').first.trim();
    final safeName = fileName.isEmpty ? 'image.jpg' : fileName;

    setState(() => _downloading = true);
    final saved = await downloadFile(
      url: widget.imageUrl,
      fileName: safeName,
      onProgress: (v) {
        if (mounted) setState(() => _downloading = v);
      },
    );
    if (mounted) setState(() => _downloading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? l10n.downloadFailed
              : l10n.downloadSuccess(saved),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          _downloading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: AppLocalizations.of(context).download,
                  onPressed: () => _download(context),
                ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(widget.imageUrl),
        ),
      ),
    );
  }
}