/// Domain rules for the KYC identity fields (E3/JEBV4-197): `id_number` is
/// REQUIRED for every [KycIdType]; the `^\d{12}$` shape applies to
/// `national_id` only (the one shape the live BFF enforces — mirrored, not
/// invented). Boundary cases pinned per the JEBV4-113 review (finding 6).
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

  group('hasValidIdNumber — passport / residency (non-empty only)', () {
    test('empty is invalid for every type (E3: id_number is a must)', () {
      for (final type in KycIdType.values) {
        expect(_draft(idType: type, idNumber: '').hasValidIdNumber, isFalse,
            reason: '${type.wire} must require a value');
      }
    });

    test('passport accepts an alphanumeric document number (no shape rule)',
        () {
      expect(
        _draft(idType: KycIdType.passport, idNumber: 'P1234567')
            .hasValidIdNumber,
        isTrue,
      );
    });

    test('residency accepts a short document number (no 12-digit rule)', () {
      expect(
        _draft(idType: KycIdType.residency, idNumber: 'R-88')
            .hasValidIdNumber,
        isTrue,
      );
    });

    test('the 12-digit rule does NOT leak onto passport (11 digits is fine)',
        () {
      expect(
        _draft(idType: KycIdType.passport, idNumber: '12345678901')
            .hasValidIdNumber,
        isTrue,
      );
    });
  });
}
