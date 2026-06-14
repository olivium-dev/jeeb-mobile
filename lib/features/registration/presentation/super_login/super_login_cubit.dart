import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../data/super_login_service.dart';
import 'super_login_state.dart';

/// Drives the super-login credential sheet (FR-P0-4).
///
/// Replaces the old gate-less client mint: it POSTs the submitted credential
/// to the gateway via [SuperLoginService], and on success persists the
/// **real** returned tokens via [AuthTokenStore]. It NEVER mints a
/// `mock-jwt-*` token and NEVER logs or compares the passcode client-side.
class SuperLoginCubit extends Cubit<SuperLoginState> {
  SuperLoginCubit({
    required SuperLoginService service,
    required AuthTokenStore tokenStore,
  })  : _service = service,
        _tokenStore = tokenStore,
        super(const SuperLoginState());

  final SuperLoginService _service;
  final AuthTokenStore _tokenStore;

  /// Validates [userId]/[passcode] against the gateway. On success the real
  /// tokens are persisted and the state moves to [SuperLoginStatus.success];
  /// the host sheet listens for that to dismiss + navigate home.
  Future<void> submit({
    required String userId,
    required String passcode,
  }) async {
    if (state.isSubmitting) return;
    if (userId.trim().isEmpty || passcode.isEmpty) {
      // Defensive: the sheet already disables submit until both are non-empty.
      emit(state.copyWith(
        status: SuperLoginStatus.error,
        error: SuperLoginError.invalidCredentials,
      ));
      return;
    }

    emit(state.copyWith(status: SuperLoginStatus.submitting, error: null));

    final result = await _service.signIn(
      userId: userId.trim(),
      passcode: passcode,
    );

    if (isClosed) return;

    switch (result) {
      case SuperLoginSuccess(:final session):
        await _tokenStore.save(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userId: session.userId,
        );
        if (isClosed) return;
        emit(state.copyWith(status: SuperLoginStatus.success, error: null));
      case SuperLoginFailure(:final error):
        emit(state.copyWith(status: SuperLoginStatus.error, error: error));
    }
  }
}
