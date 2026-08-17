/// Domain rules for the KYC identity fields (E3/JEBV4-197): `id_number` is
/// REQUIRED for every [KycIdType]; the `^\d{12}$` shape applies to
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';

KycSubmission _draft({
  KycIdType idType = KycIdType.nationalId,
  String? idNumber,
}) =>
    KycSubmission(
      status: KycStatus.notSubmitted,
      idType: idType,
      idNumber: idNumber,
    );

void main() {
  group('KycIdType wire values (E3/Q-042 ratified vocabulary)', () {
    test('exactly national_id | passport | residency', () {
      expect(
        KycIdType.values.map((t) => t.wire),
        ['national_id', 'passport', 'residency'],
      );
    });
  });

  group('hasValidIdNumber — national_id (^\\d{12}\$)', () {
    test('null / empty / whitespace are invalid', () {
      expect(_draft().hasValidIdNumber, isFalse);
      expect(_draft(idNumber: '').hasValidIdNumber, isFalse);
      expect(_draft(idNumber: '   ').hasValidIdNumber, isFalse);
    });

    test('exactly 12 digits is valid', () {
      expect(_draft(idNumber: '123456789012').hasValidIdNumber, isTrue);
    });

    test('11 digits (boundary below) is invalid', () {
      expect(_draft(idNumber: '12345678901').hasValidIdNumber, isFalse);
    });

    test('13 digits (boundary above) is invalid', () {
      expect(_draft(idNumber: '1234567890123').hasValidIdNumber, isFalse);
    });

    test('12 chars with a non-digit is invalid', () {
      expect(_draft(idNumber: '12345678901X').hasValidIdNumber, isFalse);
    });

    test('surrounding whitespace is tolerated around a valid 12-digit value',
        () {
      expect(_draft(idNumber: ' 123456789012 ').hasValidIdNumber, isTrue);
    });
  });

  // JEBV4-256: passport and residency ARE shape-checked upstream
  // (`^[A-Z0-9]{6,9}$` / `^[A-Z0-9]{6,12}$`). This group used to assert the
  // opposite — that they were unconstrained — so the client accepted `R-88`
  // and an 11-character passport, both of which the BFF answers 400 on.
  group('hasValidIdNumber — passport / residency shapes', () {
    test('empty is invalid for every type (E3: id_number is a must)', () {
      for (final type in KycIdType.values) {
        expect(_draft(idType: type, idNumber: '').hasValidIdNumber, isFalse,
            reason: '${type.wire} must require a value');
      }
    });

    test('passport accepts an alphanumeric document number in range', () {
      expect(
        _draft(idType: KycIdType.passport, idNumber: 'P1234567')
            .hasValidIdNumber,
        isTrue,
      );
    });

    test('the 12-digit national_id rule does NOT leak onto passport', () {
      // 8 digits: rejected by the national_id rule, accepted for passport.
      expect(
        _draft(idType: KycIdType.passport, idNumber: '12345678').hasValidIdNumber,
        isTrue,
      );
    });

    test('passport rejects a value past its 9-character cap', () {
      expect(
        _draft(idType: KycIdType.passport, idNumber: '12345678901')
            .hasValidIdNumber,
        isFalse,
        reason: r'11 characters exceeds the upstream ^[A-Z0-9]{6,9}$ shape',
      );
    });

    test('a punctuated document number is rejected, not silently sent', () {
      expect(
        _draft(idType: KycIdType.residency, idNumber: 'R-88').hasValidIdNumber,
        isFalse,
        reason: 'the hyphen is outside [A-Z0-9] and it is under the 6 minimum',
      );
    });

    test('residency accepts 6 to 12 uppercase alphanumerics', () {
      expect(
        _draft(idType: KycIdType.residency, idNumber: 'RES123').hasValidIdNumber,
        isTrue,
      );
      expect(
        _draft(idType: KycIdType.residency, idNumber: 'RES123456789')
            .hasValidIdNumber,
        isTrue,
      );
      expect(
        _draft(idType: KycIdType.residency, idNumber: 'RES12').hasValidIdNumber,
        isFalse,
        reason: '5 characters is under the 6 minimum',
      );
    });

    test('lowercase is rejected — the client must normalize before submit', () {
      expect(
        _draft(idType: KycIdType.passport, idNumber: 'p1234567')
            .hasValidIdNumber,
        isFalse,
        reason: 'the BFF rejects rather than normalizes; the wizard uppercases',
      );
    });
  });
}
