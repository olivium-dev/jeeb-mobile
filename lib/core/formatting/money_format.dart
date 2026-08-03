/// Single money formatter for every customer/jeeber-facing amount (receipt,
/// offers, tiers, chat order summary). Lane fix/client-polish item 3: before
/// this, screens mixed `$12.00`, `USD 12.00`, `12.0` and `$12` — every surface
/// now renders through one rule so amounts read identically everywhere.
///
/// Rule: two decimal places always, thousands grouped with commas; the `$`
/// symbol for USD (and for a missing/blank currency, which the gateway treats
/// as USD); `<CODE> <value>` for any other ISO code. Pure Dart — no
/// Flutter/intl imports so data and domain layers can use it too.
///
/// RTL safety (JEBV4-98 / F10): a money token mixes a strong-LTR symbol/ISO
/// code (`$`, `LBP`) with Western digits. Dropped verbatim into an Arabic
/// (RTL) paragraph the bidi algorithm reorders the symbol relative to the
/// digits (`$12.00` reads as `12.00$` on the wrong side, `LBP 15,000.00`
/// scrambles). Every result is therefore wrapped in a Unicode LTR *isolate*
/// ([_lri]…[_pdi]) so the amount always lays out left-to-right and keeps its
/// symbol placement regardless of the surrounding text direction, while
/// staying a plain [String] usable from data/domain layers.
///
/// Digit-policy decision (recorded per the ticket's AC): the numerals stay
/// Western/ASCII (`0-9`) in both locales — Arabic-Indic digits (`٠-٩`) are a
/// deliberate *product* call, not made here. Isolation fixes the placement
/// hazard without silently changing the digit system.
abstract final class MoneyFormat {
  /// U+2066 LEFT-TO-RIGHT ISOLATE — opens an LTR-directional run.
  static const String _lri = '\u2066';

  /// U+2069 POP DIRECTIONAL ISOLATE — closes the run opened by [_lri].
  static const String _pdi = '\u2069';

  /// Formats [amount] in [currency] — `$12.00` for USD, `LBP 15,000.00`
  /// otherwise, wrapped in an LTR isolate so it renders correctly in ar/RTL.
  ///
  /// [signed] prefixes a `+` for positive amounts, INSIDE the isolate — a
  /// cash-in row on the earnings breakdown (screen 19). `U+002B` is bidi-class
  /// ES, so concatenating it outside the isolate resolves with the paragraph
  /// direction and renders `$8.00+` in Arabic. [_group] already emits its own
  /// leading `-` for negatives, so [signed] deliberately only adds the positive
  /// sign. Defaults to false, keeping every existing call site byte-identical.
  static String format(
    double amount, {
    String currency = 'USD',
    bool signed = false,
  }) {
    final value = _group(amount.toStringAsFixed(2));
    final code = currency.trim().toUpperCase();
    final sign = signed && amount > 0 ? '+' : '';
    final token =
        (code.isEmpty || code == 'USD') ? '$sign\$$value' : '$sign$code $value';
    return '$_lri$token$_pdi';
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
