import 'package:intl/intl.dart';

class Helpers {
  static final _dateFormatter = DateFormat('dd MMM yyyy');

  static String formatDate(DateTime date) {
    return _dateFormatter.format(date);
  }

  static String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String daysLabel(int days) {
    return days == 1 ? "1 Day" : "$days Days";
  }

  static String statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return "green";
      case 'rejected':
        return "red";
      case 'recorded':
      default:
        return "blue";
    }
  }
}
