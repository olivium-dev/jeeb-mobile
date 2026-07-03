// Lane item 3 — the single money formatter for receipt, offers, tiers and
// chat surfaces. One rule: two decimals, thousands grouping, `$` for USD
// (blank currency defaults to USD), `<CODE> <value>` otherwise.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/money_format.dart';

void main() {
  group('MoneyFormat.format', () {
    test('USD renders with the dollar symbol and two decimals', () {
      expect(MoneyFormat.format(12), r'$12.00');
      expect(MoneyFormat.format(17.5, currency: 'USD'), r'$17.50');
      expect(MoneyFormat.format(9.999, currency: 'usd'), r'$10.00');
    });

    test('blank/missing currency defaults to USD (gateway convention)', () {
      expect(MoneyFormat.format(5, currency: ''), r'$5.00');
      expect(MoneyFormat.format(5, currency: '  '), r'$5.00');
    });

    test('non-USD renders as CODE value', () {
      expect(MoneyFormat.format(15000, currency: 'LBP'), 'LBP 15,000.00');
      expect(MoneyFormat.format(3.2, currency: 'aed'), 'AED 3.20');
    });

    test('thousands grouping', () {
      expect(MoneyFormat.format(1234567.89), r'$1,234,567.89');
      expect(MoneyFormat.format(999.99), r'$999.99');
      expect(MoneyFormat.format(1000), r'$1,000.00');
    });

    test('negative amounts keep the sign before the grouped digits', () {
      expect(MoneyFormat.format(-1234.5), r'$-1,234.50');
    });
  });
}
