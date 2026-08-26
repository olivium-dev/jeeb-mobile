import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_redaction.dart';
import 'package:jeeb_mobile/core/observability/session_trace/capture/obs_dio_interceptor.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';

/// Requires `flutter test --dart-define=JEEB_DEVTOOL_ENABLED=true
/// --dart-define=JEEB_OBS_OVERLAY=true …` to
/// exercise the `skip:`-guarded groups below — [kObsCompiledIn] is a frozen
String get _needsDevtoolDefine =>
    'requires --dart-define=JEEB_DEVTOOL_ENABLED=true';

const String _fakeJwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEiLCJleHAiOjk5OTk5OTk5OTl9.S3cReTtOkEnLeAk';

/// The exact leak signature a run-mission gate would grep for.
final RegExp _secretPattern = RegExp(r'Bearer |eyJ[A-Za-z0-9_-]{10,}\.');

const String _otpPhoneCanary = '+31600000000-OBS-P8R4';
const String _otpCodeCanary = 'OTP-739281-OBS-C7S3';
const String _otpHeaderCanary = 'HEADER-OTP-LEAK-884422-H9M5';
const String _prohibitedSuppressionMarker = '<sensitive-body-suppressed>';

final class _PoisonPayload {
  bool inspected = false;

  Object toJson() {
    inspected = true;
    throw StateError('sensitive payload was inspected');
  }

  @override
  String toString() {
    inspected = true;
    throw StateError('sensitive payload was stringified');
  }
}

void _expectNoOtpCanaryMaterial(ObsApiEvent event) {
  final encoded = jsonEncode(event.toJson());
  for (final secret in <String>[
    _otpPhoneCanary,
    _otpCodeCanary,
    _otpHeaderCanary,
  ]) {
    final handle = DiagRedaction.redactToken(secret);
    final hash = handle.substring(4).split('~').first;
    expect(encoded, isNot(contains(secret)));
    expect(encoded, isNot(contains(handle)));
    expect(encoded, isNot(contains(hash)));
    expect(encoded, isNot(contains(secret.substring(secret.length - 4))));
  }
  final lower = encoded.toLowerCase();
  expect(lower, isNot(contains('content-length')));
  expect(lower, isNot(contains('x-obs-request-bytes')));
  expect(lower, isNot(contains('x-obs-response-bytes')));
  expect(lower, isNot(contains('tok:')));
  expect(encoded, isNot(contains(_prohibitedSuppressionMarker)));
  expect(event.requestHeaders, isEmpty);
  expect(event.responseHeaders, isEmpty);
  expect(event.requestBody, isNull);
  expect(event.responseBody, isNull);
  expect(event.errorMessage, isNull);
}

/// Test-only: [ErrorInterceptorHandler.next] completes its internal
/// completer with an ERROR. `future` is `@protected` (subclass-only) — this
/// subclass immediately [Future.ignore]s it so a direct-unit-call test
class _SilentErrorHandler extends ErrorInterceptorHandler {
  _SilentErrorHandler() {
    future.ignore();
  }
}

class _FakeSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  String? get sessionFilePath => null;
}

RequestOptions _options({
  String method = 'GET',
  String path = '/v1/requests',
  Map<String, dynamic>? headers,
  Object? data,
}) => RequestOptions(
  method: method,
  path: path,
  headers: headers ?? <String, dynamic>{},
  data: data,
);

/// Drives a full request→response round-trip through [interceptor] and
/// returns the single [ObsApiEvent] the fake sink captured (or null if the
ObsApiEvent? _roundTrip(
  ObsDioInterceptor interceptor,
  _FakeSink sink,
  RequestOptions options, {
  int statusCode = 200,
  Object? responseData,
  Headers? responseHeaders,
}) {
  // A test that drives several round-trips through the same sink (e.g. to
  sink.events.clear();
  interceptor.onRequest(options, RequestInterceptorHandler());
  final response = Response<dynamic>(
    requestOptions: options,
    statusCode: statusCode,
    data: responseData,
    headers: responseHeaders,
  );
  interceptor.onResponse(response, ResponseInterceptorHandler());
  return sink.events.isEmpty ? null : sink.events.single as ObsApiEvent;
}

void main() {
  const interceptor = ObsDioInterceptor();
  late _FakeSink sink;

  setUp(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    sink = _FakeSink();
    Observability.instance.sink = sink;
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  group('not recording (runs in ANY invocation)', () {
    test('onRequest never mutates or short-circuits the request', () {
      final options = _options(headers: {'authorization': 'Bearer $_fakeJwt'});
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['authorization'], 'Bearer $_fakeJwt');
      expect(options.data, isNull);
      expect(handler.isCompleted, isTrue);
    });

    test('emits nothing when the runtime toggle is off', () {
      ObservabilityConfig.instance.enabled = false;
      final event = _roundTrip(interceptor, sink, _options());
      expect(event, isNull);
    });

    test('onError always forwards to handler.next', () {
      final options = _options();
      final handler = _SilentErrorHandler();
      interceptor.onError(
        DioException(requestOptions: options, type: DioExceptionType.unknown),
        handler,
      );
      expect(handler.isCompleted, isTrue);
    });
  });

  group('recording behaviour (compiled-in)', () {
    setUp(() => ObservabilityConfig.instance.enabled = true);

    test(
      'onResponse captures method/path/status/duration/seq',
      () {
        final event = _roundTrip(
          interceptor,
          sink,
          _options(method: 'get', path: '/v1/requests'),
        );

        expect(event, isNotNull);
        expect(event!.method, 'GET');
        expect(event.path, '/v1/requests');
        expect(event.statusCode, 200);
        expect(event.durationMs, greaterThanOrEqualTo(0));
        expect(event.seq, 1);
        expect(event.id, '1-api');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'query string is stripped from path and never survives anywhere',
      () {
        final options = _options(path: '/v1/auth/reset?token=super-secret-1');
        final event = _roundTrip(interceptor, sink, options);

        expect(event!.path, '/v1/auth/reset');
        final encoded = jsonEncode(event.toJson());
        expect(encoded, isNot(contains('token=')));
        expect(encoded, isNot(contains('super-secret-1')));
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'screen is captured at CALL time, not at response time',
      () {
        Observability.instance.currentScreen = '/home';
        final options = _options();
        interceptor.onRequest(options, RequestInterceptorHandler());
        Observability.instance.currentScreen = '/checkout';

        interceptor.onResponse(
          Response<dynamic>(requestOptions: options, statusCode: 200),
          ResponseInterceptorHandler(),
        );

        expect(sink.events.single, isA<ObsApiEvent>());
        expect((sink.events.single as ObsApiEvent).screen, '/home');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test('seq is stamped at REQUEST time so out-of-order responses keep '
        'their originating order', () {
      final optionsA = _options(path: '/a');
      final optionsB = _options(path: '/b');
      interceptor.onRequest(optionsA, RequestInterceptorHandler());
      interceptor.onRequest(optionsB, RequestInterceptorHandler());

      // B resolves first, A second — out of order.
      interceptor.onResponse(
        Response<dynamic>(requestOptions: optionsB, statusCode: 200),
        ResponseInterceptorHandler(),
      );
      interceptor.onResponse(
        Response<dynamic>(requestOptions: optionsA, statusCode: 200),
        ResponseInterceptorHandler(),
      );

      expect(sink.events.map((e) => e.seq), [2, 1]);
      expect(sink.events.map((e) => e.id), ['2-api', '1-api']);
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test('a transport failure (no response) emits with status:null and an '
        'errorType', () {
      final options = _options(path: '/v1/timeout-prone');
      interceptor.onRequest(options, RequestInterceptorHandler());
      interceptor.onError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'The request connection took too long.',
        ),
        _SilentErrorHandler(),
      );

      final event = sink.events.single as ObsApiEvent;
      expect(event.statusCode, isNull);
      expect(event.errorType, 'connectionTimeout');
      expect(event.errorMessage, isNotNull);
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test('a 4xx DioException with an attached response still captures '
        'status/body (redacted), not just null', () {
      final options = _options(method: 'POST', path: '/v1/orders');
      interceptor.onRequest(options, RequestInterceptorHandler());
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 422,
        data: <String, Object?>{
          'error': 'invalid amount',
          'password': 'should-never-leak',
        },
      );
      interceptor.onError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: response,
        ),
        _SilentErrorHandler(),
      );

      final event = sink.events.single as ObsApiEvent;
      expect(event.statusCode, 422);
      expect(event.errorType, 'badResponse');
      final body = event.responseBody! as Map<String, Object?>;
      expect(body['error'], 'invalid amount');
      expect(body['password'], startsWith('tok:'));
      expect(jsonEncode(body), isNot(contains('should-never-leak')));
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test(
      'correlation id is read from an x-correlation-id request header',
      () {
        final event = _roundTrip(
          interceptor,
          sink,
          _options(headers: {'x-correlation-id': 'corr-999'}),
        );
        expect(event!.correlationId, 'corr-999');
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test('byte-size markers: present (computed) for a body-bearing request, '
        'absent for a bodyless one, and prefer a wire Content-Length on the '
        'response', () {
      final withBody = _roundTrip(
        interceptor,
        sink,
        _options(method: 'POST', data: 'hello'),
      );
      expect(withBody!.requestHeaders['x-obs-request-bytes'], 5);

      final bodyless = _roundTrip(interceptor, sink, _options(path: '/b'));
      expect(
        bodyless!.requestHeaders.containsKey('x-obs-request-bytes'),
        isFalse,
      );

      final withContentLength = _roundTrip(
        interceptor,
        sink,
        _options(path: '/c'),
        responseHeaders: Headers()..add('content-length', '999'),
      );
      expect(withContentLength!.responseHeaders['x-obs-response-bytes'], 999);
    }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

    test(
      'captureApiBodies=false omits bodies but keeps headers',
      () {
        ObservabilityConfig.instance.captureApiBodies = false;
        final event = _roundTrip(
          interceptor,
          sink,
          _options(
            method: 'POST',
            headers: {'authorization': 'Bearer $_fakeJwt'},
            data: <String, Object?>{'note': 'hi'},
          ),
          responseData: <String, Object?>{'note': 'bye'},
        );

        expect(event!.requestBody, isNull);
        expect(event.responseBody, isNull);
        expect(event.requestHeaders, isNotEmpty);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    test(
      'a per-signal toggle OFF (captureApi=false) suppresses emission',
      () {
        ObservabilityConfig.instance.captureApi = false;
        final event = _roundTrip(interceptor, sink, _options());
        expect(event, isNull);
      },
      skip: kObsCompiledIn ? false : _needsDevtoolDefine,
    );

    group('P0 OTP event suppression', () {
      setUp(() {
        ObservabilityConfig.instance.captureApiBodies = true;
        ObservabilityConfig.instance.redactionEnabled = false;
      });

      test('success events suppress nested, raw, binary, and poison bodies '
          'plus arbitrary headers for versioned and unversioned aliases', () {
        final poisonRequest = _PoisonPayload();
        final poisonResponse = _PoisonPayload();
        final poisonHeader = _PoisonPayload();
        final cases = <({String path, Object request, Object response})>[
          (
            path: '/v1/auth/otp/request?phone=$_otpPhoneCanary',
            request: <String, Object?>{
              'phone': _otpPhoneCanary,
              'nested': <Object?>[_otpCodeCanary],
            },
            response: 'sent to $_otpPhoneCanary',
          ),
          (
            path: '/v1/auth/otp/verify/',
            request: '$_otpPhoneCanary:$_otpCodeCanary',
            response: List<int>.filled(739281, 0x41),
          ),
          (
            path: '/auth/otp/request',
            request: List<int>.filled(316, 0x42),
            response: poisonResponse,
          ),
          (
            path:
                'https://app.jeeb.fds-1.com/auth/otp/verify?code=$_otpCodeCanary',
            request: poisonRequest,
            response: <String, Object?>{
              'phoneHash': DiagRedaction.redactToken(_otpPhoneCanary),
              'otpSuffix': _otpCodeCanary.substring(_otpCodeCanary.length - 4),
            },
          ),
        ];

        for (final testCase in cases) {
          final options = _options(
            method: 'POST',
            path: testCase.path,
            headers: <String, dynamic>{
              'Content-Length': _otpPhoneCanary.length.toString(),
              'X-Obs-Request-Bytes': '739281',
              'x-arbitrary-phone': _otpPhoneCanary,
              'x-arbitrary-otp': _otpCodeCanary,
              'x-arbitrary-canary': _otpHeaderCanary,
              'x-arbitrary-poison': poisonHeader,
              'x-correlation-id': 'corr-otp-safe',
            },
            data: testCase.request,
          );
          final responseHeaders = Headers()
            ..add('Content-Length', _otpCodeCanary.length.toString())
            ..add('X-Obs-Response-Bytes', '739281')
            ..add('x-arbitrary-phone', _otpPhoneCanary)
            ..add('x-arbitrary-otp', _otpCodeCanary)
            ..add('x-arbitrary-canary', _otpHeaderCanary);

          final event = _roundTrip(
            interceptor,
            sink,
            options,
            responseData: testCase.response,
            responseHeaders: responseHeaders,
          )!;

          expect(event.method, 'POST');
          expect(event.path, DiagRedaction.scrubPath(testCase.path));
          expect(event.statusCode, 200);
          expect(event.durationMs, greaterThanOrEqualTo(0));
          expect(event.seq, greaterThan(0));
          expect(event.correlationId, 'corr-otp-safe');
          expect(event.errorType, isNull);
          expect(options.headers['Content-Length'], isNotNull);
          expect(responseHeaders.value('Content-Length'), isNotNull);
          _expectNoOtpCanaryMaterial(event);
        }

        expect(poisonRequest.inspected, isFalse);
        expect(poisonResponse.inspected, isFalse);
        expect(poisonHeader.inspected, isFalse);
      }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

      test('bad-response events emit null bodies/error and empty headers '
          'while retaining status, correlation, and error type', () {
        final requestPoison = _PoisonPayload();
        final responsePoison = _PoisonPayload();
        final errorPoison = _PoisonPayload();
        final options = _options(
          method: 'POST',
          path: '/v1/auth/otp/verify',
          headers: <String, dynamic>{
            'content-length': '739281',
            'x-arbitrary-phone': _otpPhoneCanary,
            'x-arbitrary-otp': _otpCodeCanary,
            'x-arbitrary-canary': _otpHeaderCanary,
            'x-request-id': 'req-otp-safe',
          },
          data: requestPoison,
        );
        interceptor.onRequest(options, RequestInterceptorHandler());
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: 422,
          data: responsePoison,
          headers: Headers()
            ..add('content-length', '739281')
            ..add('x-arbitrary-canary', _otpHeaderCanary),
        );
        interceptor.onError(
          DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
            message: 'invalid $_otpCodeCanary for $_otpPhoneCanary',
            error: errorPoison,
          ),
          _SilentErrorHandler(),
        );

        final event = sink.events.single as ObsApiEvent;
        expect(event.statusCode, 422);
        expect(event.errorType, 'badResponse');
        expect(event.correlationId, 'req-otp-safe');
        _expectNoOtpCanaryMaterial(event);
        expect(requestPoison.inspected, isFalse);
        expect(responsePoison.inspected, isFalse);
        expect(errorPoison.inspected, isFalse);
      }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);

      test(
        'timeout events never inspect a poison body or error object',
        () {
          final requestPoison = _PoisonPayload();
          final errorPoison = _PoisonPayload();
          final options = _options(
            method: 'POST',
            path: '/auth/otp/request?phone=$_otpPhoneCanary',
            headers: <String, dynamic>{
              'Content-Length': '739281',
              'x-arbitrary-phone': _otpPhoneCanary,
              'x-arbitrary-otp': _otpCodeCanary,
              'x-arbitrary-canary': _otpHeaderCanary,
              'x-correlation-id': 'corr-timeout-safe',
            },
            data: requestPoison,
          );
          interceptor.onRequest(options, RequestInterceptorHandler());
          interceptor.onError(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
              error: errorPoison,
            ),
            _SilentErrorHandler(),
          );

          final event = sink.events.single as ObsApiEvent;
          expect(event.statusCode, isNull);
          expect(event.errorType, 'connectionTimeout');
          expect(event.correlationId, 'corr-timeout-safe');
          _expectNoOtpCanaryMaterial(event);
          expect(requestPoison.inspected, isFalse);
          expect(errorPoison.inspected, isFalse);
        },
        skip: kObsCompiledIn ? false : _needsDevtoolDefine,
      );

      test(
        'requested and otpx near-matches retain ordinary observability',
        () {
          for (final path in <String>[
            '/v1/auth/otp/requested',
            '/v1/auth/otpx/request',
            '/auth/otp/requested',
            '/auth/otpx/verify',
          ]) {
            final event = _roundTrip(
              interceptor,
              sink,
              _options(
                method: 'POST',
                path: path,
                headers: <String, dynamic>{
                  'Content-Length': '23',
                  'x-correlation-id': 'corr-safe-control',
                },
                data: <String, Object?>{'note': 'safe request'},
              ),
              responseData: <String, Object?>{'note': 'safe response'},
              responseHeaders: Headers()..add('content-length', '31'),
            )!;

            expect(DiagRedaction.isBodySuppressedPath(path), isFalse);
            expect(event.requestBody, <String, Object?>{
              'note': 'safe request',
            });
            expect(event.responseBody, <String, Object?>{
              'note': 'safe response',
            });
            expect(event.requestHeaders['Content-Length'], '23');
            expect(event.requestHeaders['x-obs-request-bytes'], isA<int>());
            expect(event.responseHeaders['content-length'], '31');
            expect(event.responseHeaders['x-obs-response-bytes'], 31);
            expect(event.correlationId, 'corr-safe-control');
          }
        },
        skip: kObsCompiledIn ? false : _needsDevtoolDefine,
      );
    });

    group('SECURITY GATE: no secret survives verbatim end-to-end', () {
      test('Authorization JWT header, body token/password/fcmToken keys, and '
          'a Bearer-shaped free string never appear raw in the recorded '
          'event, even when JSON-encoded', () {
        final options = _options(
          method: 'POST',
          path: '/v1/auth/login',
          headers: {
            'authorization': 'Bearer $_fakeJwt',
            'content-type': 'application/json',
          },
          data: <String, Object?>{
            'token': 'raw-refresh-token-0001',
            'password': 'p@ssW0rd-super-secret',
            'fcmToken': 'fcm-abcdef1234567890XYZ',
            'nested': <String, Object?>{'otp': '048213'},
            'note': 'this part is fine to show',
          },
        );
        final event = _roundTrip(
          interceptor,
          sink,
          options,
          responseData: <String, Object?>{
            'accessToken': _fakeJwt,
            'freeText': 'auth via Bearer $_fakeJwt failed',
          },
        );

        final encoded = jsonEncode(event!.toJson());
        expect(encoded, isNot(contains(_fakeJwt)));
        expect(encoded, isNot(contains('raw-refresh-token-0001')));
        expect(encoded, isNot(contains('p@ssW0rd-super-secret')));
        expect(encoded, isNot(contains('fcm-abcdef1234567890XYZ')));
        expect(encoded, isNot(contains('048213')));
        expect(
          _secretPattern.hasMatch(encoded),
          isFalse,
          reason: 'no Bearer/JWT pattern may ever survive:\n$encoded',
        );
        final body = event.requestBody! as Map<String, Object?>;
        expect(body['note'], 'this part is fine to show');
      }, skip: kObsCompiledIn ? false : _needsDevtoolDefine);
    });
  });
}
