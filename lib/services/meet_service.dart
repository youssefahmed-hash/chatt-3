import 'package:url_launcher/url_launcher.dart';

class MeetService {
  static Future<void> openNewMeeting() async {
    final url = Uri.parse("https://meet.jit.si/chatt_widget.chat.id");

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> joinMeeting(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}