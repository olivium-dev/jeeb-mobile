import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/session/firebase_identity_teardown.dart';
import '../domain/account_service.dart';

class DioAccountService implements AccountService {
  DioAccountService(
    this._dio,
    this._tokenStore, {
    FirebaseIdentityTeardown? firebaseSignOut,
  }) : _firebaseSignOut = firebaseSignOut ?? signOutFirebaseIdentity;

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  final FirebaseIdentityTeardown _firebaseSignOut;

  Future<void> _tearDownFirebaseIdentity() async {
    try {
      await _firebaseSignOut();
    } catch (e) {
      Diag.event('firebase_signout_failed', {
        'kind': AppFailure.of(e).kind.name,
      });
    }
  }

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async {
    try {
      final userId = await _tokenStore.userId;
      if (userId == null) return AccountActionOutcome.notSignedIn;
      await _dio.patch<void>(
        '/v1/users/$userId/status',
        data: const <String, dynamic>{'status': 'deleted'},
      );
      await _tearDownFirebaseIdentity();
      return AccountActionOutcome.success;
    } catch (e) {
      final AppFailure failure = AppFailure.of(e);
      if (failure is ConflictFailure) {
        await _tearDownFirebaseIdentity();
        return AccountActionOutcome.alreadyPending;
      }
      Diag.event('account_delete_request_failed', {
        'kind': failure.kind.name,
      });
      return _outcomeFor(failure);
    }
  }

  static AccountActionOutcome _outcomeFor(AppFailure failure) =>
      switch (failure.kind) {
        AppFailureKind.unauthorized ||
        AppFailureKind.forbidden =>
          AccountActionOutcome.notSignedIn,
        AppFailureKind.network ||
        AppFailureKind.timeout =>
          AccountActionOutcome.networkError,
        _ => AccountActionOutcome.serverError,
      };

  @override
  Future<AccountActionOutcome> signOut() async {
    try {
      final refreshToken = await _tokenStore.refreshToken;
      await _dio.post<void>(
        '/v1/auth/logout',
        data: <String, dynamic>{'refreshToken': ?refreshToken},
      );
    } catch (e) {
      // trapped in a signed-in shell is worse than a server missing the logout.
      Diag.event('signout_revoke_failed', {'kind': AppFailure.of(e).kind.name});
    } finally {
      await _tokenStore.clear();
      await _tearDownFirebaseIdentity();
    }
    return AccountActionOutcome.success;
  }
}
