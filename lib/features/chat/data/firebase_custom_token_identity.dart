import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/chat_firebase_identity.dart';

/// Signs the app in to Firebase with a CUSTOM TOKEN minted from the Jeeb JWT.
///
/// This is the only sign-in shape that makes a client-side Firestore chat read
/// safe, because it is the only one that makes `request.auth.uid` mean the same
/// thing as `AuthorId` on a chat-service message and `Participants[].UserId` on
/// the parent conversation. A security rule can then say "the caller is a
/// participant of this conversation" and have that be true.
///
/// **What is NOT here, deliberately: `signInAnonymously()`.** It is one line and
/// it would make the stream work today. It would also mint a uid unrelated to
/// the Jeeb user, so the only rule that could admit it is
/// `allow read: if request.auth != null` — which admits every anonymous caller
/// on the internet to every Jeeb conversation, including the competing offers
/// `MessageVisibilityResolver` exists to keep private. See
/// [ChatFirebaseIdentity] for the full predicate this would bypass.
///
/// # Status (b03): wired to the live minter
///
/// The production [ChatFirebaseTokenMinter] is `GatewayChatFirebaseTokenMinter`
/// (`POST /v1/chat/firebase-token`), built in
/// `ChatDetailScreen._wrapRealtime`. When the mint returns null — expired
/// session, an older gateway, or the server-side kill switch
/// (`Firebase:Chat:ServiceAccountKeyPath` unset ⇒ 503) — this reports false, no
/// channel opens, and the existing HTTP path carries chat unchanged.
///
/// # Session lifetime is NOT bounded by the minted token
///
/// The gateway's `TokenLifetimeSeconds` bounds only the CUSTOM token, which is
/// spent once here. What `signInWithCustomToken` returns is a Firebase session
/// that the SDK then refreshes on its own, indefinitely, without ever calling
/// the gateway again — so a short custom-token lifetime is not a revocation
/// control and must not be sold as one. Revocation is the membership rule
/// alone: STAMPING `RemovedAt` on that participant in the conversation document
/// is what actually ends their read access.
class FirebaseCustomTokenIdentity implements ChatFirebaseIdentity {
  FirebaseCustomTokenIdentity({
    required FirebaseAuth auth,
    required ChatFirebaseTokenMinter minter,
  })  : _auth = auth,
        _minter = minter;

  final FirebaseAuth _auth;
  final ChatFirebaseTokenMinter _minter;

  @override
  Future<bool> ensureSignedIn() async {
    // Already signed in — a custom-token session survives app restarts, so the
    // common case costs no round trip at all.
    if (_auth.currentUser != null) return true;
    try {
      final token = await _minter.mintCustomToken();
      // No token is the EXPECTED state today, not an error: it is what "the
      // backend has no mint endpoint" looks like from here.
      if (token == null || token.isEmpty) {
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'no_token',
        });
        return false;
      }
      final credential = await _auth.signInWithCustomToken(token);
      final ok = credential.user != null;
      Diag.event('chat_firebase_identity', <String, Object?>{
        'result': ok ? 'signed_in' : 'no_user',
      });
      return ok;
    } catch (error) {
      // Never rethrow: a failed sign-in must degrade to "no realtime", and a
      // raw plugin exception escaping here would take the chat screen with it.
      Diag.event('chat_firebase_identity', <String, Object?>{
        'result': 'failed',
        'error': error.runtimeType.toString(),
      });
      return false;
    }
  }
}
