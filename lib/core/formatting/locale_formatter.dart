import 'package:intl/intl.dart';

class LocaleFormatter {

  LocaleFormatter({this.locale = 'en'});
  final String locale;

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
}
