import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/file_download.dart';

/// Displays a file message: icon, filename, size and download action.
class FileMessageCard extends StatefulWidget {
  final String? url;
  final String? fileName;
  final int? fileSize;
  final String? fileType;

  const FileMessageCard({
    super.key,
    this.url,
    this.fileName,
    this.fileSize,
    this.fileType,
  });

  @override
  State<FileMessageCard> createState() => _FileMessageCardState();
}

class _FileMessageCardState extends State<FileMessageCard> {
  bool _downloading = false;

  String _fullUrl(String path) =>
      path.startsWith('http') ? path : '${ApiConfig.baseUrl}$path';

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  IconData _icon() {
    final type = (widget.fileType ?? '').toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('image')) return Icons.image;
    if (type.contains('audio')) return Icons.audiotrack;
    if (type.contains('video')) return Icons.movie;
    if (type.contains('zip') || type.contains('compressed')) return Icons.folder_zip;
    if (type.contains('word') || type.contains('doc')) return Icons.description;
    if (type.contains('excel') || type.contains('sheet')) return Icons.table_chart;
    if (type.contains('text')) return Icons.article;
    return Icons.insert_drive_file;
  }

  Future<void> _download(BuildContext context) async {
    final target = widget.url;
    final name = widget.fileName;
    if (target == null || name == null) return;

    setState(() => _downloading = true);
    final saved = await downloadFile(
      url: _fullUrl(target),
      fileName: name,
      onProgress: (v) {
        if (mounted) setState(() => _downloading = v);
      },
    );
    if (!mounted) return;
    setState(() => _downloading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Download failed'
              : 'Saved: $saved',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        (widget.fileName == null || widget.fileName!.isEmpty)
            ? 'File'
            : widget.fileName!;

    return GestureDetector(
      onTap: () => _download(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(), color: theme.colorScheme.secondary, size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (_formatSize(widget.fileSize).isNotEmpty)
                    Text(
                      _formatSize(widget.fileSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
