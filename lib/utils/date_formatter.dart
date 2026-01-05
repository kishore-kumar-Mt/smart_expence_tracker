import 'package:intl/intl.dart';

class DateFormatter {
  static String formatNotification(DateTime date) {
    return DateFormat('dd MMM yyyy • HH:mm').format(date);
  }
}
