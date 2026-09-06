// F2 — a 200 that says `verified:false` is a REFUSED handover, not a success.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_state.dart';
import 'package:jeeb_mobile/features/otp_handover/data/dio_otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';

import '_scripted_dio.dart';

/// A repository that answers `success:false` WITHOUT throwing — the belt and
/// braces the cubit keeps for a fake that predates the throwing contract.
class _UnverifiedRepository implements OtpHandoverRepository {
  const _UnverifiedRepository();

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async =>
      const OtpFetchResult(smsTriggered: true);

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async => const OtpHandoverResult(success: false);
}

void main() {
  test('200 {verified:false} makes submitOtp THROW invalidOtp', () async {
    final dio = scriptedDio((options, responder) {
      responder.respondWith(200, body: <String, Object?>{
        'verified': false,
        'message': 'server prose that must never be rendered',
      });
    });
    final repo = DioOtpHandoverRepository(dio);

    await expectLater(
      repo.submitOtp(deliveryId: 'DLV-1', otp: '1234'),
      throwsA(
        isA<OtpHandoverException>().having(
          (e) => e.kind,
          'kind',
          OtpHandoverErrorKind.invalidOtp,
        ),
      ),
    );
  });

  test('200 {verified:true} resolves', () async {
    final dio = scriptedDio((options, responder) {
      responder.respondWith(200, body: <String, Object?>{'verified': true});
    });
    final result =
        await DioOtpHandoverRepository(dio).submitOtp(
      deliveryId: 'DLV-1',
      otp: '1234',
    );
    expect(result.success, isTrue);
  });

  test('the cubit lands ready/wrongAttempts:1/invalidOtp and keeps the code',
      () async {
    final cubit = OtpHandoverCubit(
      repository: const _UnverifiedRepository(),
      deliveryId: 'DLV-1',
      isClient: false,
    );
    await cubit.submitOtp('1234');

    expect(cubit.state.mode, OtpHandoverViewMode.ready);
    expect(cubit.state.wrongAttempts, 1);
    expect(cubit.state.errorKind, OtpHandoverErrorKind.invalidOtp);
    // A refused code is NOT a success: the screen must not have advanced.
    expect(cubit.state.mode, isNot(OtpHandoverViewMode.success));
    await cubit.close();
  });
}
