// BUG-8 (sprint-008 run-7) regression guard — goods-cost currency delivery read
// route (belt-and-suspenders; same latent singular-read class).
//
// `fetchCurrency` read the SINGULAR `GET /v1/delivery/{id}`, which the live
// origin gateway (`:10090`) 404s — the delivery aggregate lives at the PLURAL
// `GET /v1/deliveries/{id}` (Contract 8c). This pins the READ to the plural
// route on the origin base and preserves the legacy `:4010` mock singular alias.
//
// The `POST /v1/delivery/{id}/goods-cost` command is a GENUINELY different
// endpoint and MUST stay singular — asserted here so the rewrite never leaks.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/goods_cost/data/dio_goods_cost_repository.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioGoodsCostRepository originRepo() =>
      DioGoodsCostRepository(dio, originGateway: true);
  DioGoodsCostRepository mockRepo() =>
      DioGoodsCostRepository(dio, originGateway: false);

  test('origin: fetchCurrency reads the PLURAL GET /v1/deliveries/{id} — NOT the '
      'singular that 404s on the live gateway (BUG-8)', () async {
    await originRepo().fetchCurrency(_deliveryId);

    expect(adapter.getPaths, contains('/v1/deliveries/$_deliveryId'));
    expect(adapter.getPaths, isNot(contains('/v1/delivery/$_deliveryId')));
  });

  test('mock: fetchCurrency keeps the singular alias when originGateway:false',
      () async {
    await mockRepo().fetchCurrency(_deliveryId);

    expect(adapter.getPaths, contains('/v1/delivery/$_deliveryId'));
    expect(adapter.getPaths, isNot(contains('/v1/deliveries/$_deliveryId')));
  });

  test('the goods-cost POST stays SINGULAR (genuinely different endpoint, NOT '
      'base-rewritten)', () async {
    await originRepo().recordGoodsCost(deliveryId: _deliveryId, amount: 12.0);

    expect(
      adapter.postPaths,
      contains('/v1/delivery/$_deliveryId/goods-cost'),
    );
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
    return _json({'id': _deliveryId, 'currency': 'USD', 'amount': 12.0});
  }
}
