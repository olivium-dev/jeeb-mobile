// BUG-8 (sprint-008 run-7) regression guard — delivery-receipt delivery read

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioDeliveryReceiptRepository originRepo() =>
      DioDeliveryReceiptRepository(dio, originGateway: true);
  DioDeliveryReceiptRepository mockRepo() =>
      DioDeliveryReceiptRepository(dio, originGateway: false);

  test('origin: fetchReceipt reads the PLURAL GET /v1/deliveries/{id} — NOT the '
      'singular that 404s on the live gateway (BUG-8)', () async {
    await originRepo().fetchReceipt(_deliveryId);

    expect(adapter.getPaths, contains('/v1/deliveries/$_deliveryId'));
    expect(adapter.getPaths, isNot(contains('/v1/delivery/$_deliveryId')));
  });

  test('mock: fetchReceipt keeps the singular alias when originGateway:false',
      () async {
    await mockRepo().fetchReceipt(_deliveryId);

    expect(adapter.getPaths, contains('/v1/delivery/$_deliveryId'));
    expect(adapter.getPaths, isNot(contains('/v1/deliveries/$_deliveryId')));
  });

  test('confirmReceipt PATCHes the real /v1/deliveries/{id}/status route and '
      'POSTs NEITHER fictional COD/transition route', () async {
    await originRepo().confirmReceipt(
      const DeliveryReceipt(
        deliveryId: _deliveryId,
        jeeberName: 'Sami',
        jeeberId: 'j-1',
        cashAmount: 5.0,
        currency: 'USD',
        status: 'AtDoor',
      ),
    );

    expect(adapter.patchPaths, contains('/v1/deliveries/$_deliveryId/status'));
    // The fictional 404 routes are gone.
    expect(adapter.postPaths, isNot(contains('/v1/delivery/status/transition')));
    expect(adapter.postPaths, isNot(contains('/v1/payments/cod_jeeb/record')));
  });
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  final List<String> getPaths = <String>[];
  final List<String> postPaths = <String>[];
  final List<String> patchPaths = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') getPaths.add(options.path);
    if (options.method == 'POST') postPaths.add(options.path);
    if (options.method == 'PATCH') patchPaths.add(options.path);
    return _json({'id': _deliveryId, 'status': 'AtDoor'});
  }
}
