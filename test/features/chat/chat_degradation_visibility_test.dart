// Every silent `return null` in the chat identity chain must now name itself.
// Behaviour is unchanged: each case still degrades to plain HTTP chat.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/chat_diagnostics.dart';
import 'package:jeeb_mobile/features/chat/data/gateway_chat_firebase_token_minter.dart';

Dio _dioAnswering({
  Map<String, dynamic>? body,
  int statusCode = 200,
  bool throwPlain = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (throwPlain) throw StateError('transport exploded');
        final response = Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: statusCode,
          data: body,
        );
        if (statusCode >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(response);
      },
    ),
  );
  return dio;
}

List<String> _reasonsFor(String stage) => ChatDiagnostics.events
    .where((event) => event.stage == stage)
    .map((event) => event.reason)
    .toList();

void main() {
  setUp(() {
    ChatDiagnostics.resetForTest();
    ChatDiagnostics.sink = (_) {};
  });
  tearDown(ChatDiagnostics.resetForTest);

  group('mint', () {
    test(
      'a 200 with no token records mint/no_token and still returns null',
      () async {
        final minter = GatewayChatFirebaseTokenMinter(
          dio: _dioAnswering(body: <String, dynamic>{}),
        );
        expect(await minter.mintCustomToken(), isNull);
        expect(_reasonsFor(ChatDiagStage.mint), <String>['no_token']);
        expect(ChatDiagnostics.events.single.status, 200);
      },
    );

    test('an HTTP error records the status that caused it', () async {
      final minter = GatewayChatFirebaseTokenMinter(
        dio: _dioAnswering(statusCode: 503),
      );
      expect(await minter.mintCustomToken(), isNull);
      expect(_reasonsFor(ChatDiagStage.mint).single, startsWith('http_'));
      expect(ChatDiagnostics.events.single.status, 503);
    });

    test('a non-Dio throw is recorded rather than swallowed', () async {
      final minter = GatewayChatFirebaseTokenMinter(
        dio: _dioAnswering(throwPlain: true),
      );
      expect(await minter.mintCustomToken(), isNull);
      expect(_reasonsFor(ChatDiagStage.mint), isNotEmpty);
    });

    test('a successful mint records nothing', () async {
      final minter = GatewayChatFirebaseTokenMinter(
        dio: _dioAnswering(body: <String, dynamic>{'token': 'jwt'}),
      );
      expect(await minter.mintCustomToken(), 'jwt');
      expect(ChatDiagnostics.events, isEmpty);
    });
  });
}
