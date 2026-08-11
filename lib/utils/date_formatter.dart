import 'package:intl/intl.dart';

class DateFormatter {
  static String formatLastSeen(String? value) {
    if (value == null || value.isEmpty) {
      return "Unknown";
    }

    final date = DateTime.parse(value).toLocal();
    final now = DateTime.now();

    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today at ${DateFormat('h:mm a').format(date)}";
    }

    if (difference.inDays == 1) {
      return "Yesterday at ${DateFormat('h:mm a').format(date)}";
    }

    return DateFormat("d MMM • h:mm a").format(date);
  }
}