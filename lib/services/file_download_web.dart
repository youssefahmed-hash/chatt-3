import 'dart:html' as html;

import 'package:http/http.dart' as http;

Future<String?> downloadFile({
  required String url,
  required String fileName,
  void Function(bool downloading)? onProgress,
}) async {
  onProgress?.call(true);
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;

    final bytes = res.bodyBytes;
    final blob = html.Blob([bytes]);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: objectUrl)
      ..download = fileName
      ..style.display = 'none';
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(objectUrl);
    return fileName;
  } catch (_) {
    return null;
  } finally {
    onProgress?.call(false);
  }
}