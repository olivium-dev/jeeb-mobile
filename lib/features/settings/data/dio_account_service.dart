import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../core/session/firebase_identity_teardown.dart';
import '../domain/account_service.dart';

/// Dio-backed [AccountService] for the settings surface (T-mobile-031).
///
/// Replaces the prior `FakeAccountService` as the DI default so the settings
/// screen's destructive actions hit the real jeeb-gateway instead of always
/// returning success. Speaks the gateway contract paths only — the
/// `MockGatewayClient` rewrite interceptor maps them to the `:4010` service
/// prefixes (40_GUARDRAILS_ARCH §4/§11: never hardcode a service prefix/host).
///
/// Unlike the fail-safe [AccountSessionTerminator] seam (JM-062, which always
/// drops the local session even when the network call fails), this seam
/// surfaces the network outcome to the cubit so the settings UI can render a
/// `networkError` banner. The local token clear still runs on the success path
/// of [signOut] so the session is genuinely dropped.
class DioAccountService implements AccountService {
  DioAccountService(
    this._dio,
    this._tokenStore, {
    FirebaseIdentityTeardown? firebaseSignOut,
  }) : _firebaseSignOut = firebaseSignOut ?? signOutFirebaseIdentity;

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  /// Ends the SECOND identity this app holds. Jeeb signs in to Firebase with a
  /// custom token minted from the Jeeb JWT, and that session outlives the token
  /// store by design (the SDK refreshes it forever, never calling the gateway
  /// again) — so clearing the keystore alone leaves the previous user still
  /// authorised by the Firestore membership rule. Injectable so a test can
  /// assert it was actually called: the default is a no-op in-suite because
  /// `Firebase.apps` is empty in every widget test.
  final FirebaseIdentityTeardown _firebaseSignOut;

  /// Runs [_firebaseSignOut] and swallows anything it throws.
  ///
  /// Load-bearing in BOTH callers. In [signOut] it sits in a `finally`, where an
  /// escaping error would replace the returned outcome and strand the user in a
  /// signed-in shell — the exact JEBV4-245 failure the fail-safe contract
  /// exists to prevent. In [requestAccountDeletion] it sits inside the `try`,
  /// where an escaping error would be caught as `networkError` and report "the
  /// deletion did not go through" about a deletion the gateway already
  /// accepted. The production default already swallows everything, but the seam
  /// is injectable and the guarantee has to hold at the call site, not by
  /// convention.
  Future<void> _tearDownFirebaseIdentity() async {
    try {
      await _firebaseSignOut();
    } catch (_) {
      // Deliberate: see above.
    }
  }

  /// `PATCH /users/{userId}/status { status: 'deleted' }` (D5). A 409 from the
  /// gateway means a deletion is already queued → [AccountActionOutcome.alreadyPending]
  /// so the cubit latches the row without re-firing. Any transport/5xx failure
  /// maps to [AccountActionOutcome.networkError].
  ///
  /// On the two outcomes that mean "this account is going away" (queued now, or
  /// already queued) the Firebase identity is torn down too. A deleted account's
  /// custom-token session would otherwise keep refreshing itself and stay
  /// authorised by the Firestore membership rule for every conversation it was
  /// a participant of — the account row is gone, the chat read is not.
  /// `networkError` deliberately does NOT tear down: nothing was queued, the
  /// user stays signed in, and killing their Firebase session there would only
  /// drop realtime chat to HTTP for no reason.
  @override
  Future<AccountActionOutcome> requestAccountDeletion() async {
    try {
      final userId = await _tokenStore.userId;
      if (userId == null) return AccountActionOutcome.networkError;
      await _dio.patch<void>(
        '/v1/users/$userId/status',
        data: const <String, dynamic>{'status': 'deleted'},
      );
      await _tearDownFirebaseIdentity();
      return AccountActionOutcome.success;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await _tearDownFirebaseIdentity();
        return AccountActionOutcome.alreadyPending;
      }
      return AccountActionOutcome.networkError;
    } catch (_) {
      return AccountActionOutcome.networkError;
    }
  }

  /// `POST /v1/auth/logout { refreshToken }`, best-effort. Sign-out is
  /// **fail-safe** (JEBV4-245): the local keystore is ALWAYS cleared (in the
  /// `finally`) and the outcome is ALWAYS [AccountActionOutcome.success] — even
  /// when the server logout fails, times out, or 5xx's. A failed network
  /// round-trip must NEVER strand the user signed-in; a server that never hears
  /// the logout is acceptable (the token is dead client-side). Mirrors the
  /// fail-safe [AccountSessionTerminator] contract.
  ///
  /// The Firebase identity is dropped in the SAME `finally` as the keystore,
  /// and for the same reason: this app holds two sessions, and until b03 only
  /// one of them was being ended. Both are unconditional — a logout that clears
  /// the Jeeb token but leaves a live Firebase session behind is worse than no
  /// logout at all, because the next user of this install inherits it
  /// (`FirebaseCustomTokenIdentity.ensureSignedIn` short-circuits on
  /// `currentUser != null`).
  @override
  Future<AccountActionOutcome> signOut() async {
    try {
      final refreshToken = await _tokenStore.refreshToken;
      await _dio.post<void>(
        '/v1/auth/logout',
        data: <String, dynamic>{'refreshToken': ?refreshToken},
      );
    } catch (_) {
      // Swallow — the local clear below is the load-bearing step; a user
      // trapped in a signed-in shell is worse than a server missing the logout.
    } finally {
      await _tokenStore.clear();
      await _tearDownFirebaseIdentity();
    }
    return AccountActionOutcome.success;
  }
}
