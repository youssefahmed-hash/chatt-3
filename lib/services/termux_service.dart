import 'dart:io';
import 'package:flutter/services.dart';

class TermuxService {
  static HttpServer? _assetServer;

  /// Starts a temporary local HTTP server on port 4990 to serve the bundled server.zip to Termux.
  static Future<void> startLocalAssetServer() async {
    if (_assetServer != null) return;
    try {
      _assetServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 4990);
      _assetServer!.listen((HttpRequest request) async {
        if (request.uri.path == '/server.zip') {
          try {
            final ByteData data = await rootBundle.load('assets/server.zip');
            final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
            request.response
              ..headers.contentType = ContentType('application', 'zip')
              ..headers.contentLength = bytes.length
              ..add(bytes);
          } catch (e) {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('Asset load failed: $e');
          } finally {
            await request.response.close();
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
      print('Local asset server started on http://127.0.0.1:4990');
    } catch (e) {
      print('Error starting local asset server: $e');
      rethrow;
    }
  }

  /// Stops the temporary asset server.
  static Future<void> stopLocalAssetServer() async {
    await _assetServer?.close(force: true);
    _assetServer = null;
    print('Local asset server stopped');
  }
}
