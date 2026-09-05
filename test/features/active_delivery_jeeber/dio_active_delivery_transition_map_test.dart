// The transition mapper: a 409 is the sprint-009 accept-race vocabulary — the
// row already moved — not a server fault.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';

import '../otp_handover/_scripted_dio.dart';

class _NoopCdn implements CdnAssetGateway {
  const _NoopCdn();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused');
}

Future<ActiveDeliveryException> _transitionFailure(
  void Function(RequestOptions, ResponseHandler) respond,
) async {
  final repo = DioActiveDeliveryRepository(
    scriptedDio(respond),
    cdnAssetGateway: const _NoopCdn(),
    originGateway: true,
  );
  try {
    await repo.transition(
      deliveryId: 'DLV-1',
      from: JeeberDeliveryStatus.picked,
      to: JeeberDeliveryStatus.inTransit,
    );
  } on ActiveDeliveryException catch (e) {
    return e;
  }
  fail('expected an ActiveDeliveryException');
}

void main() {
  test('409 is a refused transition, not a server error', () async {
    final e = await _transitionFailure(
      (_, r) => r.failWithStatus(409, body: problem('delivery-already-moved')),
    );
    expect(e.failure, ActiveDeliveryFailure.invalidTransition);
    expect(e.typeSuffix, 'delivery-already-moved');
    expect(e.toString(), isNot(contains('server prose')));
  });

  test('a bare 409 with no problem body still lands on invalidTransition',
      () async {
    final e = await _transitionFailure((_, r) => r.failWithStatus(409));
    expect(e.failure, ActiveDeliveryFailure.invalidTransition);
  });

  test('500 stays the server kind', () async {
    final e = await _transitionFailure((_, r) => r.failWithStatus(500));
    expect(e.failure, ActiveDeliveryFailure.server);
  });
}
