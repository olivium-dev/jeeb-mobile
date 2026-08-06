// Gateway evidence is captured server-side during dispute creation.

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

  test('evidence preview performs no client-side gateway fanout', () async {
    final evidence = await DioEscalateRepository(
      dio,
    ).fetchEvidence(deliveryId: _deliveryId);

    expect(evidence.isEmpty, isTrue);
    expect(adapter.getPaths, isEmpty);
    expect(adapter.getQueries, isEmpty);
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
