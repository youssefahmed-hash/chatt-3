import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<String?> downloadFile({
  required String url,
  required String fileName,
  void Function(bool downloading)? onProgress,
}) async {
  onProgress?.call(true);
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;

    final dir = await getApplicationDocumentsDirectory();
    final safeName =
        fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final file =
        File('${dir.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(res.bodyBytes);
    return file.path;
  } catch (_) {
    return null;
  } finally {
    onProgress?.call(false);
  }
}