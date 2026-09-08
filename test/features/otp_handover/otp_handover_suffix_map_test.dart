// AE-12 — the `type` suffix decides the kind; `data['message']` never does.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/otp_handover/data/dio_otp_handover_repository.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';

import '_scripted_dio.dart';

Future<OtpHandoverException> _submitFailure(
  void Function(RequestOptions, ResponseHandler) respond,
) async {
  final repo = DioOtpHandoverRepository(scriptedDio(respond));
  try {
    await repo.submitOtp(deliveryId: 'DLV-1', otp: '1234');
  } on OtpHandoverException catch (e) {
    return e;
  }
  fail('expected an OtpHandoverException');
}

Future<OtpHandoverException> _fetchFailure(
  void Function(RequestOptions, ResponseHandler) respond,
) async {
  final repo = DioOtpHandoverRepository(scriptedDio(respond));
  try {
    await repo.fetchHandoverCode(deliveryId: 'DLV-1');
  } on OtpHandoverException catch (e) {
    return e;
  }
  fail('expected an OtpHandoverException');
}

void main() {
  test('not-at-door and handover-wrong-party get their own kinds', () async {
    expect(
      (await _submitFailure(
        (_, r) => r.failWithStatus(409, body: problem('not-at-door')),
      )).kind,
      OtpHandoverErrorKind.notAtDoor,
    );
    expect(
      (await _submitFailure(
        (_, r) => r.failWithStatus(409, body: problem('handover-wrong-party')),
      )).kind,
      OtpHandoverErrorKind.wrongParty,
    );
  });

  test('404 is notFound, not the blanket server kind', () async {
    expect(
      (await _submitFailure((_, r) => r.failWithStatus(404))).kind,
      OtpHandoverErrorKind.notFound,
    );
  });

  test('a transport failure is network, a 500 is server', () async {
    expect(
      (await _submitFailure(
        (_, r) => r.failWithType(DioExceptionType.connectionError),
      )).kind,
      OtpHandoverErrorKind.network,
    );
    expect(
      (await _submitFailure((_, r) => r.failWithStatus(500))).kind,
      OtpHandoverErrorKind.server,
    );
  });

  test('server prose is never carried onto the exception', () async {
    final failure = await _submitFailure(
      (_, r) => r.failWithStatus(409, body: problem('not-at-door')),
    );
    expect(failure.toString(), isNot(contains('server prose')));
  });

  test('a 401 is "wrong code" only on VERIFY; on the READ it is a dead session',
      () async {
    expect(
      (await _submitFailure((_, r) => r.failWithStatus(401))).kind,
      OtpHandoverErrorKind.invalidOtp,
    );
    expect(
      (await _fetchFailure((_, r) => r.failWithStatus(401))).kind,
      OtpHandoverErrorKind.unauthorized,
      reason: 'an expired session must not read as an invalid code',
    );
  });

  test('the unauthorized kind renders the sign-in copy family, not validation',
      () {
    expect(
      otpHandoverFailure(OtpHandoverErrorKind.unauthorized),
      isA<UnauthorizedFailure>(),
    );
  });
}
