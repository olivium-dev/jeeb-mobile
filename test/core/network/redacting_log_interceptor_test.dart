import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_redaction.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/core/network/redacting_log_interceptor.dart';

/// Security regression test for the dev-logging token leak: the debug HTTP
/// logger must NEVER print a full bearer JWT or an FCM registration token.
///
/// Captures `debugPrint` output (a reassignable global in flutter foundation)
/// while driving the interceptor over the exact shapes that used to leak.
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

  test(
      'Authorization header is logged as the exact tok:<fnv8>~<last4> handle, '
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
    // redaction layer produces for this header value...
    expect(all, contains(DiagRedaction.redactToken(headerValue)));
    // ...which matches the documented `tok:<fnv8>~<last4>` shape (last4 of
    // the header value = last 4 chars of the JWT).
    expect(
      RegExp('tok:[0-9a-f]{8}~BEEF').hasMatch(all),
      isTrue,
      reason: 'expected a tok:<8-hex>~<last4> handle in: $all',
    );
    // And no fragment of the secret beyond the last 4 chars ever prints.
    expect(all, isNot(contains(jwt)));
    expect(all, isNot(contains('LEAKED-signature')));
  });

  test(
      'createDio wires RedactingLogInterceptor and NEVER the raw '
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
      reason: 'the raw LogInterceptor printed full Authorization headers '
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
}
