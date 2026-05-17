import 'package:intl/intl.dart';

class LocaleFormatter {
  final String locale;

  LocaleFormatter({this.locale = 'en'});

  String formatCurrency(double amount, {String currency = 'LBP'}) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: currency == 'LBP' ? 'LBP ' : '\$',
      decimalDigits: currency == 'LBP' ? 0 : 2,
    );
    return formatter.format(amount);
  }

  String formatDate(DateTime date) {
    return DateFormat.yMMMd(locale).format(date);
  }

  String formatTime(DateTime time) {
    return DateFormat.Hm(locale).format(time);
  }

  String formatDateTime(DateTime dateTime) {
    return DateFormat.yMMMd(locale).add_Hm().format(dateTime);
  }

  String formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return locale == 'ar' ? 'الآن' : 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return formatDate(dateTime);
  }
}
