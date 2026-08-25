import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_redaction.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/core/network/redacting_log_interceptor.dart';

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
