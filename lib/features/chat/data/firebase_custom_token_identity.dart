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
///
/// # The session is per-INSTALL, not per-user, so it must be checked
///
/// `signInWithCustomToken` puts a Firebase session on the DEVICE, and the SDK
/// keeps it alive across app restarts and across Jeeb logouts. So
/// "`currentUser != null`" answers "does this install hold a Firebase session",
/// NOT "is the current Jeeb user signed in to Firebase" — and after a logout /
/// account switch those are different users. Taking the first for the second is
/// how the next signed-in user inherits the previous one's uid and reads, under
/// the membership rule, every conversation that user was a participant of.
/// [jeebUserId] is what makes the two questions the same question: a session
/// whose uid is not the CURRENT Jeeb subject is discarded and re-minted.
class FirebaseCustomTokenIdentity implements ChatFirebaseIdentity {
  FirebaseCustomTokenIdentity({
    required FirebaseAuth auth,
    required ChatFirebaseTokenMinter minter,
    required String jeebUserId,
  })  : _auth = auth,
        _minter = minter,
        _jeebUserId = jeebUserId;

  final FirebaseAuth _auth;
  final ChatFirebaseTokenMinter _minter;

  /// The CURRENT Jeeb session subject (the JWT `sub`, as read from
  /// `AuthTokenStore`). The gateway mints the custom token with this as its
  /// `uid`, so it is exactly what `request.auth.uid` must equal for a rule that
  /// compares against `Participants[].UserId` to mean anything.
  final String _jeebUserId;

  @override
  Future<bool> ensureSignedIn() async {
    // Fail closed on an unknown subject. Without it there is nothing to compare
    // an existing session against, and "reuse whatever session this install
    // happens to hold" is the exact bug this parameter exists to close.
    if (_jeebUserId.isEmpty) {
      Diag.event('chat_firebase_identity', <String, Object?>{
        'result': 'no_jeeb_user',
      });
      return false;
    }
    try {
      final existing = _auth.currentUser;
      if (existing != null) {
        // Already signed in AS THIS USER — a custom-token session survives app
        // restarts, so the common case still costs no round trip at all.
        if (existing.uid == _jeebUserId) return true;
        // Someone else's session, inherited from before a logout or an account
        // switch. Drop it FIRST: re-minting on top of a live foreign session
        // would leave that uid in place if the mint then fails, which is the
        // state we are trying to make unreachable.
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'uid_mismatch',
        });
        await _auth.signOut();
      }
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
      final user = credential.user;
      if (user == null) {
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'no_user',
        });
        return false;
      }
      // The mint is server-side and derives the uid from the validated bearer's
      // own claims, so this should always hold. Check it anyway: it is the ONE
      // assertion that `request.auth.uid` will mean what every rule in the
      // ruleset assumes it means, and a false here is a wrong-user read, not a
      // missing feature. Fail closed and leave no session behind.
      if (user.uid != _jeebUserId) {
        Diag.event('chat_firebase_identity', <String, Object?>{
          'result': 'minted_uid_mismatch',
        });
        await _auth.signOut();
        return false;
      }
      Diag.event('chat_firebase_identity', <String, Object?>{
        'result': 'signed_in',
      });
      return true;
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
