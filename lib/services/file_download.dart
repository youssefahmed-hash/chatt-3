import 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart' as download_impl;

/// Downloads a file from [url] to the user's device and returns the saved
/// location/path for display, or null on failure.
///
/// - Web: fetches the bytes and triggers a browser download using a blob URL
///   so [fileName] is preserved.
/// - Native (Android/iOS/macOS/Linux/Windows): saves to the app documents
///   directory and returns the absolute file path.
///
/// A [onProgress] callback can be used to show a spinner while the file is
/// being fetched.
Future<String?> downloadFile({
  required String url,
  required String fileName,
  void Function(bool downloading)? onProgress,
}) {
  return download_impl.downloadFile(
    url: url,
    fileName: fileName,
    onProgress: onProgress,
  );
}