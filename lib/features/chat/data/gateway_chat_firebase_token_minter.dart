import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/chat_firebase_identity.dart';

/// The route that trades a Jeeb bearer JWT for a Firebase custom token.
///
/// `POST`, no body: the gateway derives the uid from the validated bearer's own
/// claims and nothing the client sends. That is the whole security property —
/// see [GatewayChatFirebaseTokenMinter].
const String kChatFirebaseTokenPath = '/v1/chat/firebase-token';

/// The production [ChatFirebaseTokenMinter]: the mint endpoint the ports in
/// `chat_firebase_identity.dart` were written against, now that it exists.
///
/// # Why the uid is not sent, and must never be
///
/// This posts an EMPTY body. The gateway reads the subject out of the bearer it
/// just validated (`sid` → `sub`, deliberately NOT the trusted-edge `X-User-Id`
/// header) and mints the Firebase custom token on that. A client that could name
/// its own uid could mint an identity for any Jeeb user, and since the Firestore
/// rules authorise a chat read purely on
/// `request.auth.uid == Participants[].UserId`, that would be a read of any
/// conversation on the product. So the request carries no identity input at all.
///
/// # Why every failure returns null instead of throwing
///
/// null is the DESIGNED degrade, not an error swallow. The three failures that
/// actually happen in the field are all "no realtime, keep HTTP":
///
///   * **401** — the session expired, or this build is talking to a gateway that
///     predates the route (it 401s unauthenticated requests BEFORE routing, so a
///     401 does not even prove the route is absent);
///   * **503** — the gateway is deployed but `Firebase:Chat:ServiceAccountKeyPath`
///     is unset. This is the server-side KILL SWITCH: unsetting one env line
///     turns the whole feature off for already-installed APKs;
///   * **404 / timeout / offline** — an older gateway, or no network.
///
/// In every one of them [ChatFirebaseIdentity.ensureSignedIn] returns false,
/// [FirestoreChatRealtimeSource] never touches Firestore (its `firestore`
/// callback is resolved only AFTER the identity check), `ChatCubit._realtimeLive`
/// stays false, and `_refreshFromPush` keeps doing the push-driven HTTP read it
/// does today. Behaviour degrades to exactly the current build. Throwing here
/// would instead take the chat screen down over a feature that is optional.
///
/// The status is emitted on the diagnostic stream because a device run needs to
/// tell those cases apart: "no realtime" is the same on screen whether the
/// gateway is old, the key is unset, or the token was rejected, and guessing
/// which one from a silent screen is how a bad deploy gets called a client bug.
class GatewayChatFirebaseTokenMinter implements ChatFirebaseTokenMinter {
  GatewayChatFirebaseTokenMinter({required Dio dio}) : _dio = dio;

  /// The AUTHENTICATED gateway Dio (`getIt<Dio>()`) — the same instance the
  /// chat gateway uses, so the bearer this mint is derived from is the bearer
  /// the rest of chat runs as.
  final Dio _dio;

  @override
  Future<String?> mintCustomToken() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        kChatFirebaseTokenPath,
      );
      // snake_case on the wire: `{"token","uid","expires_at",
      // "expires_in_seconds"}`. Only `token` is consumed — `uid` is the
      // gateway's echo of what it derived and is NOT trusted as an input to
      // anything here; the authority on the signed-in uid is the Firebase SDK
      // after `signInWithCustomToken`.
      final token = response.data?['token'];
      if (token is! String || token.isEmpty) {
        Diag.event('chat_firebase_mint', <String, Object?>{
          'result': 'no_token',
          'status': response.statusCode,
        });
        return null;
      }
      Diag.event('chat_firebase_mint', <String, Object?>{
        'result': 'minted',
        'status': response.statusCode,
      });
      return token;
    } on DioException catch (error) {
      Diag.event('chat_firebase_mint', <String, Object?>{
        'result': 'http_error',
        // The number that says WHICH degrade this is: 401 session/old-gateway,
        // 503 kill switch engaged, 404 route absent, null transport failure.
        'status': error.response?.statusCode,
        'type': error.type.name,
      });
      return null;
    } catch (error) {
      Diag.event('chat_firebase_mint', <String, Object?>{
        'result': 'failed',
        'error': error.runtimeType.toString(),
      });
      return null;
    }
  }
}
