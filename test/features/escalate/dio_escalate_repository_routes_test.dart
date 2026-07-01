// BUG-8 (sprint-008 run-7) regression guard — escalate timeline delivery read
// route (belt-and-suspenders; same latent singular-read class).
//
// The dispute auto-attach timeline read used the SINGULAR `GET /v1/delivery/{id}`,
// which the live origin gateway (`:10090`) 404s — the delivery aggregate lives
// at the PLURAL `GET /v1/deliveries/{id}` (Contract 8c). This pins the timeline
// READ to the plural route on the origin base and preserves the legacy `:4010`
// mock singular alias. The dispute POST + chat-snapshot reads are genuinely
// different endpoints and are untouched.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/escalate/data/dio_escalate_repository.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioEscalateRepository originRepo() =>
      DioEscalateRepository(dio, originGateway: true);
  DioEscalateRepository mockRepo() =>
      DioEscalateRepository(dio, originGateway: false);

  test('origin: timeline reads the PLURAL GET /v1/deliveries/{id} — NOT the '
      'singular that 404s on the live gateway (BUG-8)', () async {
    await originRepo().fetchEvidence(deliveryId: _deliveryId);

    expect(adapter.getPaths, contains('/v1/deliveries/$_deliveryId'));
    expect(adapter.getPaths, isNot(contains('/v1/delivery/$_deliveryId')));
  });

  test('mock: timeline keeps the singular alias when originGateway:false',
      () async {
    await mockRepo().fetchEvidence(deliveryId: _deliveryId);

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
    // by-request conversation resolve → no id, so the snapshot read is skipped;
    // the timeline delivery read (the assertion target) still fires.
    return _json({'id': _deliveryId, 'status': 'Done'});
  }
}
