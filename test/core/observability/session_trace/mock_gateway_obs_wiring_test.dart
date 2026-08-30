import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/core/observability/session_trace/capture/obs_dio_interceptor.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';

String get _needsDevtoolDefines =>
    'requires JEEB_DEVTOOL_ENABLED=true and JEEB_OBS_OVERLAY=true';

final class _FakeSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  String? get sessionFilePath => '/tmp/mock-gateway-obs.jsonl';
}

final class _JsonAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'outcome': 'accepted',
        'email': 'response-canary@example.invalid',
      }),
      201,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'x-correlation-id': <String>['corr-real-client'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    Observability.instance.setSessionForTest('mock-gateway-session');
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  test(
    'the product Dio contains exactly one trace interceptor when compiled',
    () {
      final dio = MockGatewayClient.createDio(
        baseUrl: 'http://localhost:10090',
      );
      final count = dio.interceptors.whereType<ObsDioInterceptor>().length;
      expect(count, kObsCompiledIn ? 1 : 0);
    },
  );

  test('attachTo is compile-gated and idempotent', () {
    final dio = Dio();
    ObsDioInterceptor.attachTo(dio);
    ObsDioInterceptor.attachTo(dio);
    expect(
      dio.interceptors.whereType<ObsDioInterceptor>(),
      hasLength(kObsCompiledIn ? 1 : 0),
    );
  });

  test('product Dio observes main and refresh attempts before recovery', () {
    final source = File('lib/core/network/dio_client.dart').readAsStringSync();
    final refreshObs = source.indexOf(
      'ObsDioInterceptor.attachTo(refreshClient);',
    );
    final refreshFallback = source.indexOf(
      'refreshClient.interceptors.add(',
      refreshObs,
    );
    final mainObs = source.indexOf('ObsDioInterceptor.attachTo(dio);');
    final tokenRefresh = source.indexOf('TokenRefreshInterceptor(', mainObs);
    final mainFallback = source.indexOf(
      'UnversionedPathFallbackInterceptor(dio)',
      mainObs,
    );

    expect(refreshObs, greaterThanOrEqualTo(0));
    expect(refreshFallback, greaterThan(refreshObs));
    expect(mainObs, greaterThanOrEqualTo(0));
    expect(tokenRefresh, greaterThan(mainObs));
    expect(mainFallback, greaterThan(mainObs));
  });

  test(
    'a real product-client request records sanitized request and response data',
    () async {
      final sink = _FakeSink();
      Observability.instance.sink = sink;
      Observability.instance.currentScreen = '/request-detail';
      ObservabilityConfig.instance.enabled = true;
      final dio = MockGatewayClient.createDio(baseUrl: 'http://localhost:10090')
        ..httpClientAdapter = _JsonAdapter();

      await dio.post<Map<String, dynamic>>(
        '/v1/requests',
        data: <String, Object?>{'kind': 'parcel', 'phone': '+31 6 1234 5678'},
      );

      expect(sink.events, hasLength(1));
      final event = sink.events.single as ObsApiEvent;
      expect(event.method, 'POST');
      expect(event.path, '/v1/requests');
      expect(event.statusCode, 201);
      expect(event.durationMs, greaterThanOrEqualTo(0));
      expect(event.correlationId, 'corr-real-client');
      expect(event.screen, '/request-detail');
      expect(event.requestBody, containsPair('kind', 'parcel'));
      expect(event.requestBody, containsPair('phone', SecretRedactor.redacted));
      expect(event.responseBody, containsPair('outcome', 'accepted'));
      expect(
        event.responseBody,
        containsPair('email', SecretRedactor.redacted),
      );
    },
    skip: kObsCompiledIn ? false : _needsDevtoolDefines,
  );
}
