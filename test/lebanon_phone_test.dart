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

    test('never truncates when the user pastes too many digits', () {
      expect(LebanonPhone.normalise('7112345678'), '7112345678');
    });

    test('returns empty string for non-digit input', () {
      expect(LebanonPhone.normalise('abc'), '');
    });

    test('keeps partial input as-typed', () {
      expect(LebanonPhone.normalise('711'), '711');
    });
  });

  group('LebanonPhone.tryParse', () {
    test('returns null for too-short input (< 7 national digits)', () {
      expect(LebanonPhone.tryParse('711234'), isNull); // 6 digits
      expect(LebanonPhone.tryParse('71123'), isNull); // 5 digits
    });

    test('accepts a 7-digit national number', () {
      final p = LebanonPhone.tryParse('3000002');
      expect(p, isNotNull);
      expect(p!.digits, '3000002');
      expect(p.e164, '+9613000002');
    });

    test('accepts the +9613000002 seed phone (7 national digits)', () {
      // The valid seed phone the gateway issues OTP for — its national part is
      final p = LebanonPhone.tryParse('+9613000002');
      expect(p, isNotNull);
      expect(p!.e164, '+9613000002');
    });

    test(
      'returns a valid LebanonPhone for a clean 8-digit national number',
      () {
        final p = LebanonPhone.tryParse('71123456');
        expect(p, isNotNull);
        expect(p!.digits, '71123456');
        expect(p.e164, '+96171123456');
        expect(p.displayWithPrefix, '+961 71123456');
      },
    );

    test(
      'returns a valid LebanonPhone when the user typed the +961 prefix',
      () {
        final p = LebanonPhone.tryParse('+961 71 123 456');
        expect(p, isNotNull);
        expect(p!.e164, '+96171123456');
      },
    );

    test('rejects overflow instead of silently truncating it', () {
      expect(LebanonPhone.tryParse('7112345678'), isNull);
    });

    test('rejects an explicit non-Lebanon E.164 identity', () {
      expect(LebanonPhone.normalise('+31 6 1234 5678'), isEmpty);
      expect(LebanonPhone.tryParse('+31 6 1234 5678'), isNull);
    });

    test('rejects misplaced or repeated plus signs', () {
      expect(LebanonPhone.tryParse('71+123456'), isNull);
      expect(LebanonPhone.tryParse('++96171123456'), isNull);
    });
  });
}
