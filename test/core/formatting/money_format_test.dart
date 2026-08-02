// Lane item 3 — the single money formatter for receipt, offers, tiers and

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/money_format.dart';

/// Wraps [token] in the same LTR isolate marks [MoneyFormat.format] emits.
String ltr(String token) => '\u2066$token\u2069';

void main() {
  group('MoneyFormat.format', () {
    test('USD renders with the dollar symbol and two decimals', () {
      expect(MoneyFormat.format(12), ltr(r'$12.00'));
      expect(MoneyFormat.format(17.5, currency: 'USD'), ltr(r'$17.50'));
      expect(MoneyFormat.format(9.999, currency: 'usd'), ltr(r'$10.00'));
    });

    test('blank/missing currency defaults to USD (gateway convention)', () {
      expect(MoneyFormat.format(5, currency: ''), ltr(r'$5.00'));
      expect(MoneyFormat.format(5, currency: '  '), ltr(r'$5.00'));
    });

    test('non-USD renders as CODE value', () {
      expect(MoneyFormat.format(15000, currency: 'LBP'), ltr('LBP 15,000.00'));
      expect(MoneyFormat.format(3.2, currency: 'aed'), ltr('AED 3.20'));
    });

    test('thousands grouping', () {
      expect(MoneyFormat.format(1234567.89), ltr(r'$1,234,567.89'));
      expect(MoneyFormat.format(999.99), ltr(r'$999.99'));
      expect(MoneyFormat.format(1000), ltr(r'$1,000.00'));
    });

    test('negative amounts keep the sign before the grouped digits', () {
      expect(MoneyFormat.format(-1234.5), ltr(r'$-1,234.50'));
    });

    test('wraps the token in an LTR isolate for RTL safety (F10)', () {
      final out = MoneyFormat.format(12);
      expect(out.codeUnitAt(0), 0x2066, reason: 'opens with LRI');
      expect(out.codeUnitAt(out.length - 1), 0x2069, reason: 'closes with PDI');
    });
  });
}
