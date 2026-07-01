// BUG-8 (sprint-008 run-7) regression guard — standalone order-summary delivery
// read route.
//
// The order-summary detail (JM-031, reached from the delivery-detail hub / chat
// "view summary" on the customer Core Flow) read the SINGULAR
// `GET /v1/delivery/{id}` as its HARD dependency, which the live origin gateway
// (`:10090`) answers with 404 — aborting the whole summary (matches the lone
// abort-on-404 delivery read in run-7 `wire-step6-customer-tracking.txt`). The
// materialized aggregate is served ONLY at the PLURAL `GET /v1/deliveries/{id}`
// (Contract 8c). This pins the read to the plural route on the origin base and
// preserves the legacy `:4010` mock singular alias, at the WIRE level.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_summary/data/dio_order_summary_repository.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioOrderSummaryRepository originRepo() =>
      DioOrderSummaryRepository(dio, originGateway: true);
  DioOrderSummaryRepository mockRepo() =>
      DioOrderSummaryRepository(dio, originGateway: false);

  test('origin: reads the PLURAL GET /v1/deliveries/{id} — NOT the singular '
      '/v1/delivery/{id} that 404s on the live gateway (BUG-8)', () async {
    await originRepo().fetchSummary(_deliveryId);

    expect(adapter.getPaths, contains('/v1/deliveries/$_deliveryId'));
    expect(
      adapter.getPaths,
      isNot(contains('/v1/delivery/$_deliveryId')),
      reason: 'BUG-8: the singular route 404s on the live origin gateway',
    );
  });

  test('mock: keeps the singular GET /v1/delivery/{id} alias when '
      'originGateway:false', () async {
    await mockRepo().fetchSummary(_deliveryId);

    expect(adapter.getPaths, contains('/v1/delivery/$_deliveryId'));
    expect(adapter.getPaths, isNot(contains('/v1/deliveries/$_deliveryId')));
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

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') getPaths.add(options.path);
    if (options.path.contains('/offers')) {
      return _json(const {'items': <Object?>[]});
    }
    // The hard delivery dep must return a body so fetchSummary reaches its
    // best-effort enrichment reads (which we also record).
    return _json({'id': _deliveryId, 'requestId': _deliveryId});
  }
}
