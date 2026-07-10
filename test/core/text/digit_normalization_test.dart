import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/text/digit_normalization.dart';

TextEditingValue _value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  group('normalizeArabicIndicDigits', () {
    test('maps Eastern Arabic-Indic digits (U+0660–U+0669) to ASCII', () {
      expect(normalizeArabicIndicDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('maps Extended (Persian/Urdu) digits (U+06F0–U+06F9) to ASCII', () {
      expect(normalizeArabicIndicDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('mixed input normalizes digit-by-digit, other chars untouched', () {
      expect(normalizeArabicIndicDigits('١٢3٤-AB٥'), '123' '4-AB5');
    });

    test('pure-ASCII input passes through unchanged', () {
      expect(normalizeArabicIndicDigits('123456789012'), '123456789012');
      expect(normalizeArabicIndicDigits('P1234567'), 'P1234567');
    });

    test('empty input is a no-op', () {
      expect(normalizeArabicIndicDigits(''), '');
    });

    test('a full 12-digit Arabic-Indic national ID becomes 12 ASCII digits '
        r'and satisfies ^\d{12}$', () {
      final normalized = normalizeArabicIndicDigits('١٢٣٤٥٦٧٨٩٠١٢');
      expect(normalized, '123456789012');
      expect(RegExp(r'^\d{12}$').hasMatch(normalized), isTrue);
    });
  });

  group('ArabicIndicDigitsFormatter', () {
    const formatter = ArabicIndicDigitsFormatter();

    test('normalizes typed Arabic-Indic digits to ASCII', () {
      final out = formatter.formatEditUpdate(_value(''), _value('١٢٣'));
      expect(out.text, '123');
    });

    test('keeps the value untouched when already ASCII', () {
      final input = _value('123');
      final out = formatter.formatEditUpdate(_value('12'), input);
      expect(out.text, '123');
    });

    test('length-preserving: cursor position stays valid', () {
      final out = formatter.formatEditUpdate(_value(''), _value('٤٥٦'));
      expect(out.text.length, 3);
      expect(out.selection.baseOffset, 3);
    });

    test('composed BEFORE digitsOnly, Arabic keystrokes survive the filter',
        () {
      // Simulates the identity field's formatter chain: normalize → filter.
      final normalized =
          formatter.formatEditUpdate(_value(''), _value('١٢٣٤٥٦٧٨٩٠١٢'));
      final filtered = FilteringTextInputFormatter.digitsOnly
          .formatEditUpdate(_value(''), normalized);
      expect(filtered.text, '123456789012');
    });
  });
}
