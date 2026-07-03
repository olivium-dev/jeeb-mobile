/// Single money formatter for every customer/jeeber-facing amount (receipt,
/// offers, tiers, chat order summary). Lane fix/client-polish item 3: before
/// this, screens mixed `$12.00`, `USD 12.00`, `12.0` and `$12` — every surface
/// now renders through one rule so amounts read identically everywhere.
///
/// Rule: two decimal places always; the `$` symbol for USD (and for a missing/
/// blank currency, which the gateway treats as USD); `<CODE> <value>` for any
/// other ISO code. Pure Dart — no Flutter/intl imports so data and domain
/// layers can use it too.
abstract final class MoneyFormat {
  /// Formats [amount] in [currency] — `$12.00` for USD, `LBP 15000.00`
  /// otherwise.
  static String format(double amount, {String currency = 'USD'}) {
    final value = amount.toStringAsFixed(2);
    final code = currency.trim().toUpperCase();
    if (code.isEmpty || code == 'USD') return '\$$value';
    return '$code $value';
  }
}
