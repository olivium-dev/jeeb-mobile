// Checklist (j) — `RetryInterceptor.isReplayable` replays a POST/PATCH only
// when it carries an `Idempotency-Key`, and every one of these mutations now
// has a user-facing Retry behind it.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/retry_interceptor.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/cancellation/data/dio_cancellation_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/masked_call/data/dio_masked_call_repository.dart';
import 'package:jeeb_mobile/features/rating/data/dio_rating_repository.dart';

import 'otp_handover/_scripted_dio.dart';

/// Records every outgoing request so the header can be read back.
class _Recorder extends Interceptor {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: <String, Object?>{
          'deliveryId': 'DLV-1',
          'status': 'Done',
          'sessionId': 'SESS-1',
        },
      ),
    );
  }
}

(Dio, _Recorder) _recordingDio() {
  final _Recorder recorder = _Recorder();
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
    ..interceptors.add(recorder);
  return (dio, recorder);
}

String? _key(RequestOptions options) => options.headers.entries
    .where((MapEntry<String, dynamic> e) =>
        e.key.toLowerCase() == RetryInterceptor.idempotencyHeader.toLowerCase())
    .map((MapEntry<String, dynamic> e) => e.value?.toString())
    .firstOrNull;

class _NoopCdn implements CdnAssetGateway {
  const _NoopCdn();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused');
}

void main() {
  test('cancel carries a key, stable across a retry of the SAME cancel',
      () async {
    final (Dio dio, _Recorder recorder) = _recordingDio();
    final repo = DioCancellationRepository(dio);

    await repo.cancel(deliveryId: 'DLV-1', reason: 'changed_mind');
    await repo.cancel(deliveryId: 'DLV-1', reason: 'changed_mind');
    await repo.cancel(deliveryId: 'DLV-1', reason: 'other');

    expect(recorder.requests, hasLength(3));
    for (final RequestOptions r in recorder.requests) {
      expect(_key(r), isNotNull);
      expect(RetryInterceptor.isReplayable(r), isTrue);
    }
    expect(_key(recorder.requests[0]), _key(recorder.requests[1]));
    expect(_key(recorder.requests[0]), isNot(_key(recorder.requests[2])));
  });

  test('the rating submit carries a key derived from the rating itself',
      () async {
    final (Dio dio, _Recorder recorder) = _recordingDio();
    final repo = DioRatingRepository(dio);

    await repo.submitRating(deliveryId: 'DLV-1', stars: 5, isClient: true);
    await repo.submitRating(deliveryId: 'DLV-1', stars: 5, isClient: true);
    await repo.submitRating(deliveryId: 'DLV-1', stars: 4, isClient: true);

    expect(recorder.requests, hasLength(3));
    expect(_key(recorder.requests[0]), isNotNull);
    expect(RetryInterceptor.isReplayable(recorder.requests[0]), isTrue);
    expect(_key(recorder.requests[0]), _key(recorder.requests[1]));
    expect(_key(recorder.requests[0]), isNot(_key(recorder.requests[2])));
  });

  test('the receipt confirm carries one key per delivery', () async {
    final (Dio dio, _Recorder recorder) = _recordingDio();
    final repo = DioDeliveryReceiptRepository(dio, originGateway: true);
    const DeliveryReceipt receipt = DeliveryReceipt(
      deliveryId: 'DLV-1',
      jeeberName: 'Karim',
      cashAmount: 12.5,
      currency: 'USD',
      status: 'AtDoor',
    );

    await repo.confirmReceipt(receipt);
    await repo.confirmReceipt(receipt);

    expect(recorder.requests, hasLength(2));
    expect(_key(recorder.requests[0]), isNotNull);
    expect(RetryInterceptor.isReplayable(recorder.requests[0]), isTrue);
    expect(_key(recorder.requests[0]), _key(recorder.requests[1]));
  });

  test('a status transition carries a key derived from the edge it walks',
      () async {
    final (Dio dio, _Recorder recorder) = _recordingDio();
    final repo = DioActiveDeliveryRepository(
      dio,
      cdnAssetGateway: const _NoopCdn(),
      originGateway: true,
    );

    await repo.transition(
      deliveryId: 'DLV-1',
      from: JeeberDeliveryStatus.picked,
      to: JeeberDeliveryStatus.inTransit,
    );
    await repo.transition(
      deliveryId: 'DLV-1',
      from: JeeberDeliveryStatus.picked,
      to: JeeberDeliveryStatus.inTransit,
    );
    await repo.transition(
      deliveryId: 'DLV-1',
      from: JeeberDeliveryStatus.inTransit,
      to: JeeberDeliveryStatus.atDoor,
    );

    expect(recorder.requests, hasLength(3));
    expect(_key(recorder.requests[0]), isNotNull);
    expect(RetryInterceptor.isReplayable(recorder.requests[0]), isTrue);
    expect(_key(recorder.requests[0]), _key(recorder.requests[1]));
    expect(_key(recorder.requests[0]), isNot(_key(recorder.requests[2])));
  });

  test('a masked call carries a fresh key per START, pinned by the seam',
      () async {
    final (Dio dio, _Recorder recorder) = _recordingDio();
    int n = 0;
    final repo = DioMaskedCallRepository(dio, newKey: () => 'key-${++n}');

    await repo.startCall(orderId: 'ORD-1');
    await repo.startCall(orderId: 'ORD-1');

    expect(_key(recorder.requests[0]), 'key-1');
    expect(_key(recorder.requests[1]), 'key-2');
    expect(RetryInterceptor.isReplayable(recorder.requests[0]), isTrue);
  });

  test('without the header a POST is NOT replayable — the gap this closes',
      () {
    final Dio dio = scriptedDio((_, r) => r.respondWith(200));
    final RequestOptions bare = RequestOptions(
      path: '/v1/deliveries/DLV-1/cancel',
      method: 'POST',
      baseUrl: dio.options.baseUrl,
    );
    expect(RetryInterceptor.isReplayable(bare), isFalse);
  });
}
