abstract final class MoneyFormat {
  static const String _lri = '\u2066';

  static const String _pdi = '\u2069';

  static String format(double amount, {String currency = 'USD'}) {
    final value = _group(amount.toStringAsFixed(2));
    final code = currency.trim().toUpperCase();
    final token = (code.isEmpty || code == 'USD') ? '\$$value' : '$code $value';
    return '$_lri$token$_pdi';
  }

  static String _group(String fixed) {
    final dot = fixed.indexOf('.');
    var intPart = dot == -1 ? fixed : fixed.substring(0, dot);
    final rest = dot == -1 ? '' : fixed.substring(dot);
    final negative = intPart.startsWith('-');
    if (negative) intPart = intPart.substring(1);
    final buffer = StringBuffer(negative ? '-' : '');
    for (var i = 0; i < intPart.length; i++) {
      final remaining = intPart.length - i;
      buffer.write(intPart[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return '$buffer$rest';
  }
}
