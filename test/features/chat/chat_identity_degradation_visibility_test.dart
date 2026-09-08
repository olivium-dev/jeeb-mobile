// The identity leg of the chain: every refusal names itself, and none of them
// changes what the caller gets back (still null ⇒ plain HTTP chat).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/chat_diagnostics.dart';
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

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth({User? initial, this.mintedUid, this.throwOnSignIn = false})
    : _current = initial;

  final String? mintedUid;
  final bool throwOnSignIn;
  User? _current;

  @override
  User? get currentUser => _current;

  @override
  Future<UserCredential> signInWithCustomToken(String token) async {
    if (throwOnSignIn) throw StateError('network down');
    final uid = mintedUid;
    _current = uid == null ? null : _FakeUser(uid);
    return _FakeCredential(_current);
  }

  @override
  Future<void> signOut() async => _current = null;
}

class _StubMinter implements ChatFirebaseTokenMinter {
  _StubMinter(this._token);
  final String? _token;

  @override
  Future<String?> mintCustomToken() async => _token;
}

List<String> get _identityReasons => ChatDiagnostics.events
    .where((event) => event.stage == ChatDiagStage.identity)
    .map((event) => event.reason)
    .toList();

void main() {
  setUp(() {
    ChatDiagnostics.resetForTest();
    ChatDiagnostics.sink = (_) {};
  });
  tearDown(ChatDiagnostics.resetForTest);

  test('an empty Jeeb user id records identity/no_jeeb_user', () async {
    final sut = FirebaseCustomTokenIdentity(
      auth: _FakeAuth(),
      minter: _StubMinter('tok'),
      jeebUserId: '',
    );
    expect(await sut.ensureSignedIn(), isNull);
    expect(_identityReasons, <String>['no_jeeb_user']);
  });

  test('a leftover session for another user is recorded before sign-out', () async {
    final sut = FirebaseCustomTokenIdentity(
      auth: _FakeAuth(initial: _FakeUser(_userB), mintedUid: _userA),
      minter: _StubMinter('tok'),
      jeebUserId: _userA,
    );
    expect(await sut.ensureSignedIn(), _userA);
    expect(_identityReasons, <String>['stale_uid_signed_out']);
  });

  test('a mint that returns nothing records identity/no_token', () async {
    final sut = FirebaseCustomTokenIdentity(
      auth: _FakeAuth(),
      minter: _StubMinter(null),
      jeebUserId: _userA,
    );
    expect(await sut.ensureSignedIn(), isNull);
    expect(_identityReasons, <String>['no_token']);
  });

  test('a sign-in that yields no user records it', () async {
    final sut = FirebaseCustomTokenIdentity(
      auth: _FakeAuth(),
      minter: _StubMinter('tok'),
      jeebUserId: _userA,
    );
    expect(await sut.ensureSignedIn(), isNull);
    expect(_identityReasons, <String>['sign_in_returned_no_user']);
  });

  test('a token minted for the WRONG uid records minted_uid_mismatch', () async {
    final sut = FirebaseCustomTokenIdentity(
      auth: _FakeAuth(mintedUid: _userB),
      minter: _StubMinter('tok'),
      jeebUserId: _userA,
    );
    expect(await sut.ensureSignedIn(), isNull);
    expect(_identityReasons, <String>['minted_uid_mismatch']);
  });

  test('a throwing sign-in is recorded rather than swallowed', () async {
    final sut = FirebaseCustomTokenIdentity(
      auth: _FakeAuth(throwOnSignIn: true),
      minter: _StubMinter('tok'),
      jeebUserId: _userA,
    );
    expect(await sut.ensureSignedIn(), isNull);
    expect(_identityReasons.single, startsWith('threw_'));
  });

  test('a clean sign-in records nothing', () async {
    final sut = FirebaseCustomTokenIdentity(
      auth: _FakeAuth(mintedUid: _userA),
      minter: _StubMinter('tok'),
      jeebUserId: _userA,
    );
    expect(await sut.ensureSignedIn(), _userA);
    expect(ChatDiagnostics.events, isEmpty);
  });
}
