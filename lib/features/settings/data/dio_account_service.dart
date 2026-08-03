import 'package:dio/dio.dart';

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
    } catch (_) {
    }
  }

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

  @override
  Future<AccountActionOutcome> signOut() async {
    try {
      final refreshToken = await _tokenStore.refreshToken;
      await _dio.post<void>(
        '/v1/auth/logout',
        data: <String, dynamic>{'refreshToken': ?refreshToken},
      );
    } catch (_) {
      // trapped in a signed-in shell is worse than a server missing the logout.
    } finally {
      await _tokenStore.clear();
      await _tearDownFirebaseIdentity();
    }
    return AccountActionOutcome.success;
  }
}
