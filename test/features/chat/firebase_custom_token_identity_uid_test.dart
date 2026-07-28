// A FIREBASE SESSION IS PER-INSTALL. THE JEEB SESSION IS PER-USER.
//
// The bug this pins: `FirebaseCustomTokenIdentity.ensureSignedIn` opened with
//
//     if (_auth.currentUser != null) return true;
//
// which answers "does this DEVICE hold a Firebase session", not "is the CURRENT
// Jeeb user signed in to Firebase". Those are the same question only until
// someone logs out or switches accounts. `signInWithCustomToken` installs a
// session the SDK then refreshes on its own, indefinitely, with no further
// gateway call — so it survives a Jeeb logout, and the next user to sign in on
// that install inherited it wholesale.
//
// What that inheritance buys an attacker is not theoretical. The released
// Firestore ruleset authorises a read of `Conversations/{cid}/Messages` when
// `request.auth.uid` appears in `Participants[].UserId` with `RemovedAt` null.
// Running as user A's uid therefore reads every conversation A is still a
// participant of — while the app believes it is user B, and while the Jeeb
// bearer, the only credential anyone audits, is B's.
//
// These tests drive the identity DIRECTLY over a scripted FirebaseAuth double.
// No `Firebase.initializeApp`, no widget, no ambiguity about what ran — which
// matters here more than usual, because `Firebase.apps` is empty in every widget
// test in this repo and a screen-level test of this code path would be vacuous.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/firebase_custom_token_identity.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_firebase_identity.dart';

const _userA = 'user-a-0000-0000-0000-000000000001';
const _userB = 'user-b-0000-0000-0000-000000000002';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
}

class _FakeCredential extends Fake implements UserCredential {
  _FakeCredential(this.user);
  @override
  final User? user;
}

/// Scriptable `FirebaseAuth`: records sign-outs and the tokens it was handed,
/// and installs whatever uid [mintedUid] names on a custom-token sign-in.
class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth({User? initial, this.mintedUid}) : _current = initial;

  /// The uid the (server-side) mint is pretending to have encoded. Null models
  /// a sign-in that returns no user at all.
  final String? mintedUid;

  User? _current;
  int signOutCalls = 0;
  final List<String> tokensSpent = <String>[];

  @override
  User? get currentUser => _current;

  @override
  Future<UserCredential> signInWithCustomToken(String token) async {
    tokensSpent.add(token);
    final uid = mintedUid;
    _current = uid == null ? null : _FakeUser(uid);
    return _FakeCredential(_current);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
  }
}

class _StubMinter implements ChatFirebaseTokenMinter {
  _StubMinter(this._token);
  final String? _token;
  int calls = 0;

  @override
  Future<String?> mintCustomToken() async {
    calls++;
    return _token;
  }
}

void main() {
  group('FirebaseCustomTokenIdentity — the session must belong to THIS user',
      () {
    test('a session for the SAME uid is reused with no round trip', () async {
      // The fast path this whole class is built around must survive the fix —
      // otherwise every chat open pays a mint and the "costs no round trip at
      // all" claim in the doc becomes false.
      final auth = _FakeAuth(initial: _FakeUser(_userA));
      final minter = _StubMinter('tok');
      final sut = FirebaseCustomTokenIdentity(
        auth: auth,
        minter: minter,
        jeebUserId: _userA,
      );

      expect(await sut.ensureSignedIn(), isTrue);
      expect(minter.calls, 0, reason: 'no mint for a session already ours');
      expect(auth.signOutCalls, 0);
    });

    // THE BUG. A leftover session belonging to user A, while the Jeeb session is
    // now user B. The old code returned true here and handed A's uid to every
    // subsequent Firestore read.
    test('a session for ANOTHER uid is discarded and re-minted', () async {
      final auth = _FakeAuth(initial: _FakeUser(_userA), mintedUid: _userB);
      final minter = _StubMinter('tok-for-b');
      final sut = FirebaseCustomTokenIdentity(
        auth: auth,
        minter: minter,
        jeebUserId: _userB,
      );

      expect(await sut.ensureSignedIn(), isTrue);
      expect(
        auth.signOutCalls,
        1,
        reason: "user A's session was ended, not reused",
      );
      expect(minter.calls, 1, reason: 'a fresh token was minted for B');
      expect(auth.tokensSpent, <String>['tok-for-b']);
      expect(auth.currentUser?.uid, _userB);
    });

    // The half that matters most: when the re-mint FAILS, the inherited session
    // must be gone anyway. Signing out only after a successful mint would leave
    // A's uid live on exactly the path where the mint is expected to fail today
    // (the route is not deployed — `POST /v1/chat/firebase-token` 404s).
    test('a foreign session is dropped even when the re-mint FAILS', () async {
      final auth = _FakeAuth(initial: _FakeUser(_userA));
      final minter = _StubMinter(null); // no mint endpoint — today's live state
      final sut = FirebaseCustomTokenIdentity(
        auth: auth,
        minter: minter,
        jeebUserId: _userB,
      );

      expect(await sut.ensureSignedIn(), isFalse);
      expect(auth.signOutCalls, 1);
      expect(
        auth.currentUser,
        isNull,
        reason: "no identity is correct here; user A's identity is not",
      );
    });

    test('a mint whose uid is NOT the Jeeb subject is refused and signed out',
        () async {
      // Should be unreachable — the gateway derives the uid from the validated
      // bearer's own claims. If it ever is reachable it is a wrong-user read,
      // so it fails closed and leaves nothing behind.
      final auth = _FakeAuth(mintedUid: _userA);
      final minter = _StubMinter('tok-claiming-a');
      final sut = FirebaseCustomTokenIdentity(
        auth: auth,
        minter: minter,
        jeebUserId: _userB,
      );

      expect(await sut.ensureSignedIn(), isFalse);
      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNull);
    });

    test('an unknown Jeeb subject signs in to nothing', () async {
      // Fail closed: with no subject there is nothing to compare a session
      // against, and "reuse whatever this install holds" is the bug itself.
      final auth = _FakeAuth(initial: _FakeUser(_userA));
      final minter = _StubMinter('tok');
      final sut = FirebaseCustomTokenIdentity(
        auth: auth,
        minter: minter,
        jeebUserId: '',
      );

      expect(await sut.ensureSignedIn(), isFalse);
      expect(minter.calls, 0, reason: 'nothing to mint for');
    });

    // CONTROL. Without a clean cold start passing, every assertion above is
    // satisfiable by an identity that simply never signs in — the feature dead,
    // which is the other way this branch has been wrong before.
    test('CONTROL: a cold install DOES sign in', () async {
      final auth = _FakeAuth(mintedUid: _userB);
      final minter = _StubMinter('tok-for-b');
      final sut = FirebaseCustomTokenIdentity(
        auth: auth,
        minter: minter,
        jeebUserId: _userB,
      );

      expect(await sut.ensureSignedIn(), isTrue);
      expect(auth.signOutCalls, 0, reason: 'nothing to discard');
      expect(minter.calls, 1);
      expect(auth.currentUser?.uid, _userB);
    });
  });
}
