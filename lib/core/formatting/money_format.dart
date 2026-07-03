/// Single money formatter for every customer/jeeber-facing amount (receipt,
/// offers, tiers, chat order summary). Lane fix/client-polish item 3: before
/// this, screens mixed `$12.00`, `USD 12.00`, `12.0` and `$12` — every surface
/// now renders through one rule so amounts read identically everywhere.
///
/// Rule: two decimal places always, thousands grouped with commas; the `$`
/// symbol for USD (and for a missing/blank currency, which the gateway treats
/// as USD); `<CODE> <value>` for any other ISO code. Pure Dart — no
/// Flutter/intl imports so data and domain layers can use it too.
abstract final class MoneyFormat {
  /// Formats [amount] in [currency] — `$12.00` for USD, `LBP 15,000.00`
  /// otherwise.
  static String format(double amount, {String currency = 'USD'}) {
    final value = _group(amount.toStringAsFixed(2));
    final code = currency.trim().toUpperCase();
    if (code.isEmpty || code == 'USD') return '\$$value';
    return '$code $value';
  }

  /// Inserts thousands separators into the integer part of a fixed-decimal
  /// string (`12345.00` → `12,345.00`). Handles a leading minus sign.
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
