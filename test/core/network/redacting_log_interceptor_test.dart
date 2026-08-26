import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_redaction.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/core/network/redacting_log_interceptor.dart';

const _phoneCanary = '+31600000000-PHONE-P7X9';
const _otpCanary = 'OTP-CODE-739281-C4Q2';
const _prohibitedSuppressionMarker = '<sensitive-body-suppressed>';

class _SilentErrorHandler extends ErrorInterceptorHandler {
  _SilentErrorHandler() {
    future.ignore();
  }
}

class _ExplosiveOtpBody {
  @override
  String toString() => throw StateError('OTP body must not be inspected');
}

void _expectNoOtpCanaryMaterial(String output) {
  for (final secret in <String>[_phoneCanary, _otpCanary]) {
    final handle = DiagRedaction.redactToken(secret);
    expect(output, isNot(contains(secret)));
    expect(output, isNot(contains(handle)));
    expect(output, isNot(contains(handle.split('~').first)));
    expect(output, isNot(contains(secret.substring(secret.length - 4))));
  }
  expect(output, isNot(contains(_prohibitedSuppressionMarker)));
}

/// Security regression test for the dev-logging token leak: the debug HTTP
void main() {
  const jwt =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEifQ.LEAKED-signature-DEADBEEF';
  const fcm = 'fcm-registration-token-SHOULD-NOT-LEAK-9999';

  late List<String> printed;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    printed = <String>[];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  const interceptor = RedactingLogInterceptor();

  test('request logging redacts the Authorization bearer JWT', () {
    final options = RequestOptions(
      path: '/api/PushNotification/register',
      method: 'PUT',
      headers: <String, dynamic>{'Authorization': 'Bearer $jwt'},
      data: <String, Object?>{'fcmToken': fcm, 'deviceId': 'd-1'},
    );

    interceptor.onRequest(options, RequestInterceptorHandler());

    final all = printed.join('\n');
    expect(all, isNotEmpty, reason: 'debug logger should still log something');
    // The two secrets must NOT appear anywhere.
    expect(all, isNot(contains('LEAKED-signature-DEADBEEF')));
    expect(all, isNot(contains('SHOULD-NOT-LEAK-9999')));
    // But a correlation handle IS present so QA can still cross-reference.
    expect(all, contains('tok:'));
    // Non-secret fields survive for debuggability.
    expect(all, contains('deviceId'));
  });

  test('Authorization header is logged as the exact tok:<fnv8>~<last4> handle, '
      'never raw', () {
    const headerValue = 'Bearer $jwt';
    final options = RequestOptions(
      path: '/v1/jeeb/wallet',
      method: 'GET',
      headers: <String, dynamic>{'Authorization': headerValue},
    );

    interceptor.onRequest(options, RequestInterceptorHandler());

    final all = printed.join('\n');
    // The logged value is EXACTLY the deterministic correlation handle the
    expect(all, contains(DiagRedaction.redactToken(headerValue)));
    // ...which matches the documented `tok:<fnv8>~<last4>` shape (last4 of
    expect(
      RegExp('tok:[0-9a-f]{8}~BEEF').hasMatch(all),
      isTrue,
      reason: 'expected a tok:<8-hex>~<last4> handle in: $all',
    );
    // And no fragment of the secret beyond the last 4 chars ever prints.
    expect(all, isNot(contains(jwt)));
    expect(all, isNot(contains('LEAKED-signature')));
  });

  test('createDio wires RedactingLogInterceptor and NEVER the raw '
      'LogInterceptor (run-22 logcat token leak)', () {
    // flutter test runs in debug mode, so the kDebugMode branch is active.
    final dio = MockGatewayClient.createDio(baseUrl: 'http://localhost:4010');
    expect(
      dio.interceptors.whereType<RedactingLogInterceptor>(),
      isNotEmpty,
      reason: 'debug HTTP logging must go through the redacting logger',
    );
    expect(
      dio.interceptors.whereType<LogInterceptor>(),
      isEmpty,
      reason:
          'the raw LogInterceptor printed full Authorization headers '
          'and token bodies to logcat',
    );
  });

  test('response logging redacts accessToken/refreshToken in the body', () {
    final options = RequestOptions(path: '/v1/auth/login', method: 'POST');
    final response = Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: <String, Object?>{
        'accessToken': jwt,
        'refreshToken': 'refresh-$jwt',
        'userId': 'u-1',
      },
    );

    interceptor.onResponse(response, ResponseInterceptorHandler());

    final all = printed.join('\n');
    expect(all, isNot(contains('LEAKED-signature-DEADBEEF')));
    expect(all, contains('tok:'));
    expect(all, contains('userId'));
  });

  test('response logging redacts distinct realtime credentials', () {
    const token = 'guardian-connect-token-RAW-1111';
    const ticket = 'channel-join-ticket-RAW-2222';
    const membershipTicket = 'membership-ticket-RAW-3333';
    final options = RequestOptions(
      path: '/v1/realtime/jeeb:chat:conversation-42',
      method: 'GET',
    );
    final response = Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: <String, Object?>{
        'token': token,
        'ticket': ticket,
        'membershipTicket': membershipTicket,
        'conversationId': 'conversation-42',
      },
    );

    interceptor.onResponse(response, ResponseInterceptorHandler());

    final all = printed.join('\n');
    for (final secret in <String>[token, ticket, membershipTicket]) {
      expect(all, isNot(contains(secret)));
      expect(all, contains(DiagRedaction.redactToken(secret)));
    }
    expect(all, contains('conversationId'));
    expect(all, contains('conversation-42'));
  });

  group('P0 — OTP endpoint logs are metadata-only', () {
    const paths = <String>[
      '/v1/auth/otp/request',
      '/v1/auth/otp/verify',
      '/auth/otp/request',
      '/auth/otp/verify',
    ];

    test('requests never inspect or log headers, bodies, or placeholders', () {
      for (final path in paths) {
        printed.clear();
        final body = _ExplosiveOtpBody();
        final options = RequestOptions(
          path: '$path?source=$_phoneCanary',
          method: 'POST',
          headers: <String, dynamic>{
            'x-arbitrary-phone': _phoneCanary,
            'x-arbitrary-otp': _otpCanary,
            'x-arbitrary-poison': _ExplosiveOtpBody(),
            'Content-Length': '739281',
          },
          data: body,
        );

        interceptor.onRequest(options, RequestInterceptorHandler());

        final line = printed.singleWhere((it) => it.startsWith('[http→]'));
        expect(line, '[http→] POST $path');
        expect(line, isNot(contains('headers=')));
        expect(line, isNot(contains('body=')));
        expect(line, isNot(contains('Content-Length')));
        expect(line, isNot(contains('x-arbitrary')));
        expect(line, isNot(contains('tok:')));
        _expectNoOtpCanaryMaterial(line);
        expect(
          options.data,
          same(body),
          reason: 'logging must not mutate data',
        );
      }
    });

    test('responses and errors omit headers, bodies, and error details', () {
      for (final path in paths) {
        printed.clear();
        final options = RequestOptions(
          path: path,
          method: 'POST',
          headers: <String, dynamic>{
            'x-arbitrary-phone': _phoneCanary,
            'x-arbitrary-otp': _otpCanary,
          },
          data: _ExplosiveOtpBody(),
        );
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: 401,
          headers: Headers()
            ..add('x-arbitrary-phone', _phoneCanary)
            ..add('x-arbitrary-otp', _otpCanary)
            ..add('Content-Length', '739281'),
          data: _ExplosiveOtpBody(),
        );

        interceptor.onResponse(response, ResponseInterceptorHandler());
        interceptor.onError(
          DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
            message: 'invalid $_otpCanary for $_phoneCanary',
            error: _ExplosiveOtpBody(),
          ),
          _SilentErrorHandler(),
        );

        final lines = printed
            .where((it) => it.startsWith('[http←]') || it.startsWith('[http✗]'))
            .toList();
        expect(lines, <String>['[http←] 401 POST $path', '[http✗] POST $path']);
        final all = lines.join('\n');
        expect(all, isNot(contains('headers=')));
        expect(all, isNot(contains('body=')));
        expect(all, isNot(contains('invalid')));
        expect(all, isNot(contains('badResponse')));
        expect(all, isNot(contains('Content-Length')));
        expect(all, isNot(contains('x-arbitrary')));
        expect(all, isNot(contains('tok:')));
        _expectNoOtpCanaryMaterial(all);
      }
    });

    test('requested and otpx near-matches retain ordinary diagnostics', () {
      for (final path in <String>[
        '/v1/auth/otp/requested',
        '/v1/auth/otpx/request',
        '/auth/otp/requested',
        '/auth/otpx/verify',
      ]) {
        printed.clear();
        interceptor.onRequest(
          RequestOptions(
            path: path,
            method: 'POST',
            headers: <String, dynamic>{'x-safe-control': 'visible'},
            data: <String, Object?>{'note': 'safe-control'},
          ),
          RequestInterceptorHandler(),
        );

        final line = printed.singleWhere((it) => it.startsWith('[http→]'));
        expect(DiagRedaction.isBodySuppressedPath(path), isFalse);
        expect(line, contains('headers='));
        expect(line, contains('x-safe-control'));
        expect(line, contains('body='));
        expect(line, contains('safe-control'));
      }
    });
  });

  // ===========================================================================
  group('P4/P5 — binary bodies are never stringified', () {
    test('a Uint8List response body logs as `<binary N bytes>`', () {
      final options = RequestOptions(
        path: '/api/cdn/assets/content/chat_attachment/abc.jpg',
        method: 'GET',
        responseType: ResponseType.bytes,
      );
      // A recognisable, non-zero payload so a leaked dump is unmistakable.
      final payload = Uint8List(1024);
      for (var i = 0; i < payload.length; i++) {
        payload[i] = 0x5A;
      }
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: payload,
      );

      interceptor.onResponse(response, ResponseInterceptorHandler());

      final all = printed.join('\n');
      expect(all, contains('<binary 1024 bytes>'));
      expect(
        all,
        isNot(contains('90, 90, 90')),
        reason: 'the raw byte values must never reach logcat',
      );
      // A sanity bound: the whole line stays tiny regardless of payload size.
      expect(all.length, lessThan(300));
    });

    test(
      'a plain List<int> request body is summarized too (the signed PUT)',
      () {
        final options = RequestOptions(
          path: '/api/cdn/upload/put-signed/chat_attachment',
          method: 'PUT',
          data: List<int>.filled(2048, 0x41),
        );

        interceptor.onRequest(options, RequestInterceptorHandler());

        final all = printed.join('\n');
        expect(all, contains('<binary 2048 bytes>'));
        expect(all, isNot(contains('65, 65, 65')));
      },
    );
  });
}
