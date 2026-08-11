import 'package:url_launcher/url_launcher.dart';

class JitsiService {

  static Future<void> joinRoom(String roomName) async {

    final uri = Uri.parse(
      "https://meet.jit.si/$roomName",
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}