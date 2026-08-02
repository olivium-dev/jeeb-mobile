// BUG-8 (sprint-008 run-7) regression guard — escalate timeline delivery read

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

  test('chat snapshot resolves the conversation via the canonical '
      'GET /v1/conversations?correlationKey — NOT the nonexistent by-request '
      'route that 404s (Lane C / PR-C3)', () async {
    await originRepo().fetchEvidence(deliveryId: _deliveryId);

    expect(adapter.getPaths, contains('/v1/conversations'),
        reason: 'conversation resolve must use the correlation-key route');
    expect(
      adapter.getPaths.any((p) => p.contains('/conversations/by-request/')),
      isFalse,
      reason: 'the by-request route does not exist on the live gateway',
    );
    // The correlation key is the request id (== the customer deliveryId).
    final convCalls =
        adapter.getQueries.where((q) => q.containsKey('correlationKey'));
    expect(convCalls, isNotEmpty);
    expect(convCalls.first['correlationKey'], _deliveryId);
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
  final List<Map<String, dynamic>> getQueries = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      getPaths.add(options.path);
      getQueries.add(Map<String, dynamic>.from(options.queryParameters));
    }
    // by-request conversation resolve → no id, so the snapshot read is skipped;
    return _json({'id': _deliveryId, 'status': 'Done'});
  }
}
