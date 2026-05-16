import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/registration/domain/lebanon_phone.dart';

void main() {
  group('LebanonPhone.normalise', () {
    test('strips the +961 prefix and separators', () {
      expect(LebanonPhone.normalise('+961 71-123 456'), '71123456');
    });

    test('strips the 961 prefix without +', () {
      expect(LebanonPhone.normalise('96171123456'), '71123456');
    });

    test('drops a leading 0 (common from local-format pastes)', () {
      expect(LebanonPhone.normalise('071123456'), '71123456');
    });

    test('truncates to 8 digits when the user pastes too many', () {
      expect(LebanonPhone.normalise('7112345678'), '71123456');
    });

    test('returns empty string for non-digit input', () {
      expect(LebanonPhone.normalise('abc'), '');
    });

    test('keeps partial input as-typed', () {
      expect(LebanonPhone.normalise('711'), '711');
    });
  });

  group('LebanonPhone.tryParse', () {
    test('returns null for too-short input', () {
      expect(LebanonPhone.tryParse('711234'), isNull);
    });

    test('returns null for too-long input that does not start with +961/0', () {
      // 9 digits, no recognisable prefix → after normalise still 9 → truncated
      // to 8 → would parse, so this case must be one that genuinely fails:
      expect(LebanonPhone.tryParse('1234567'), isNull);
    });

    test('returns a valid LebanonPhone for a clean 8-digit national number',
        () {
      final p = LebanonPhone.tryParse('71123456');
      expect(p, isNotNull);
      expect(p!.digits, '71123456');
      expect(p.e164, '+96171123456');
      expect(p.displayWithPrefix, '+961 71123456');
    });

    test('returns a valid LebanonPhone when the user typed the +961 prefix',
        () {
      final p = LebanonPhone.tryParse('+961 71 123 456');
      expect(p, isNotNull);
      expect(p!.e164, '+96171123456');
    });
  });
}
