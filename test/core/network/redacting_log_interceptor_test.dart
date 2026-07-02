import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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
