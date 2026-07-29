import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/gateway_chat_firebase_token_minter.dart';

/// A Dio that answers the mint route from a canned response and RECORDS what the
/// client sent — the recording is the point, not the answering: the security
/// claim under test is about the request, not the reply.
class _MintDio {
  _MintDio({
    required this.body,
    this.statusCode = 200,
    this.throwPlain = false,
  }) {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          paths.add(options.path);
          methods.add(options.method);
          sentBodies.add(options.data);
          if (throwPlain) {
            throw StateError('transport exploded');
          }
          final response = Response<dynamic>(
            data: body,
            statusCode: statusCode,
            requestOptions: options,
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
  }

  final Object? body;
  final int statusCode;
  final bool throwPlain;
  late final Dio dio;
  int requests = 0;
  final List<String> paths = <String>[];
  final List<String> methods = <String>[];
  final List<Object?> sentBodies = <Object?>[];
}

void main() {
  group('GatewayChatFirebaseTokenMinter', () {
    test('returns the token from a 200 and calls POST /v1/chat/firebase-token',
        () async {
      final wire = _MintDio(body: <String, dynamic>{
        'token': 'custom-token-abc',
        'uid': 'user-123',
        'expires_at': '2026-07-28T20:00:00Z',
        'expires_in_seconds': 3600,
      });

      final token =
          await GatewayChatFirebaseTokenMinter(dio: wire.dio).mintCustomToken();

      expect(token, 'custom-token-abc');
      expect(wire.requests, 1, reason: 'one mint is one request, never a loop');
      expect(wire.paths.single, '/v1/chat/firebase-token');
      expect(wire.methods.single, 'POST');
    });

    test('sends NO body — the uid can only be server-derived', () async {
      // THE security assertion. The gateway derives the uid from the bearer's
      // own claims; a client that could name a uid could mint an identity for
      // any Jeeb user, and the Firestore rule authorises a conversation read
      // purely on `request.auth.uid == Participants[].UserId`. So this client
      // must supply no identity input at all — not an empty map, nothing.
      final wire = _MintDio(body: <String, dynamic>{'token': 't'});

      await GatewayChatFirebaseTokenMinter(dio: wire.dio).mintCustomToken();

      expect(wire.sentBodies.single, isNull);
    });

    test('401 degrades to null rather than throwing', () async {
      // An expired session, OR a gateway that predates the route: the live
      // gateway 401s unauthenticated requests BEFORE routing, so a 401 does not
      // even prove the route is absent. Either way: no realtime, keep HTTP.
      final wire = _MintDio(body: <String, dynamic>{}, statusCode: 401);

      expect(
        await GatewayChatFirebaseTokenMinter(dio: wire.dio).mintCustomToken(),
        isNull,
      );
    });

    test('503 (server-side kill switch) degrades to null', () async {
      // `Firebase:Chat:ServiceAccountKeyPath` unset on the gateway. This is the
      // primary rollback lever: one env line turns the feature off for APKs
      // that are already installed, and it MUST land as "no realtime", never as
      // a crash.
      final wire = _MintDio(body: <String, dynamic>{}, statusCode: 503);

      expect(
        await GatewayChatFirebaseTokenMinter(dio: wire.dio).mintCustomToken(),
        isNull,
      );
    });

    test('404 (older gateway) degrades to null', () async {
      final wire = _MintDio(body: <String, dynamic>{}, statusCode: 404);

      expect(
        await GatewayChatFirebaseTokenMinter(dio: wire.dio).mintCustomToken(),
        isNull,
      );
    });

    test('a 200 with no usable token is null, not an empty token', () async {
      // An empty string would sail into `signInWithCustomToken('')` and surface
      // as a plugin error instead of as the designed degrade.
      for (final body in <Object?>[
        <String, dynamic>{},
        <String, dynamic>{'token': ''},
        <String, dynamic>{'token': 42},
        null,
      ]) {
        final wire = _MintDio(body: body);
        expect(
          await GatewayChatFirebaseTokenMinter(dio: wire.dio).mintCustomToken(),
          isNull,
          reason: 'body $body must not produce a token',
        );
      }
    });

    test('a raw throw in the transport is also contained', () async {
      // A non-DioException thrown mid-request. Observed behaviour, not assumed:
      // Dio WRAPS it into `DioException(type: unknown, response: null)`, so this
      // lands on the DioException arm with a null status — the same shape an
      // offline device produces. (The minter's bare `catch` is therefore a
      // belt-and-braces guard that this seam cannot reach; it is kept because a
      // null-safety or JSON-shape error on the decode side would not be a
      // DioException at all.)
      final wire = _MintDio(body: null, throwPlain: true);

      expect(
        await GatewayChatFirebaseTokenMinter(dio: wire.dio).mintCustomToken(),
        isNull,
      );
    });
  });
}
