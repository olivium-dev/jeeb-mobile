// The BFF validates `id_number` per `id_type` and REJECTS rather than
// normalizes (JEBV4-256), documenting that "the client already normalizes".
// The client did not: passport/residency values were passed through verbatim,
// so a lowercase document number the user reasonably typed reached the wire and
// came back as a field-scoped 400.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

KycWizardCubit _buildCubit() {
  final cubit = KycWizardCubit(
    pickerService: StubPhotoPickerService(),
    gateway: FakeKycGateway(),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('id_number normalization', () {
    test('a lowercase passport number is uppercased before it can be sent', () {
      final cubit = _buildCubit();
      cubit.setIdType(KycIdType.passport);

      cubit.setIdNumber('p1234567');

      expect(cubit.state.submission.idNumber, 'P1234567');
      expect(cubit.state.submission.hasValidIdNumber, isTrue,
          reason: r'after normalization the value satisfies ^[A-Z0-9]{6,9}$');
    });

    test('NEGATIVE CONTROL: national_id is left alone (digits only)', () {
      final cubit = _buildCubit();

      cubit.setIdNumber('123456789012');

      expect(cubit.state.submission.idNumber, '123456789012');
    });

    test('switching type re-normalizes the value already typed', () {
      final cubit = _buildCubit();
      cubit.setIdType(KycIdType.nationalId);
      cubit.setIdNumber('123456789012');

      // The user realises it is a passport and switches. Without the
      // re-normalization the stale value would sit there under the new shape.
      cubit.setIdType(KycIdType.passport);

      expect(cubit.state.submission.idNumber, '123456789012');
      expect(cubit.state.submission.hasValidIdNumber, isFalse,
          reason: '12 characters is past the passport 9 cap, and the CTA '
              'must reflect that rather than deferring to a server 400');
    });

    test('a residency number typed in mixed case normalizes and validates', () {
      final cubit = _buildCubit();
      cubit.setIdType(KycIdType.residency);

      cubit.setIdNumber('res123abc');

      expect(cubit.state.submission.idNumber, 'RES123ABC');
      expect(cubit.state.submission.hasValidIdNumber, isTrue);
    });
  });
}
