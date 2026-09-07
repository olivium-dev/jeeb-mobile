import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import 'social_auth_error.dart';
import 'social_auth_service.dart';
import 'social_auth_state.dart';
import 'social_auth_token_store.dart';
import 'social_provider.dart';

class SocialAuthCubit extends Cubit<SocialAuthState> {
  SocialAuthCubit({
    required SocialAuthService service,
    required SocialAuthTokenStore tokenStore,
  })  : _service = service,
        _tokenStore = tokenStore,
        super(const SocialAuthState());

  final SocialAuthService _service;
  final SocialAuthTokenStore _tokenStore;

  Future<void> signInWith(SocialProvider provider) async {
    if (state.isBusy) return;
    emit(SocialAuthState(
      status: SocialAuthStatus.inProgress,
      activeProvider: provider,
    ));

    final SocialAuthResult result;
    try {
      result = await _service.signIn(provider);
    } catch (e) {
      // AUTH-01: an unguarded throw here left BOTH buttons stuck in progress.
      _failed(provider, e, 'social_signin_threw');
      return;
    }

    switch (result) {
      case SocialAuthSuccess(session: final session):
        try {
          await _tokenStore.save(session);
        } catch (e) {
          _failed(provider, e, 'social_signin_token_save_failed');
          return;
        }
        // Cubit does not navigate; screen inspects requiresPhoneVerification (JM-018, JM-009).
        emit(SocialAuthState(
          status: SocialAuthStatus.authenticated,
          activeProvider: provider,
          session: session,
        ));
      case SocialAuthFailure(error: SocialAuthError.cancelled):
        emit(const SocialAuthState());
      case SocialAuthFailure(error: SocialAuthError.collision):
        // 409 collision: NOT error banner; routed to social-collision-prompt sheet (JM-018, JM-019, D22).
        emit(SocialAuthState(
          status: SocialAuthStatus.collision,
          activeProvider: provider,
          error: SocialAuthError.collision,
        ));
      case SocialAuthFailure(error: final error):
        emit(SocialAuthState(
          status: SocialAuthStatus.failed,
          activeProvider: provider,
          error: error,
        ));
    }
  }

  void _failed(SocialProvider provider, Object error, String event) {
    Diag.event(event, {'kind': AppFailure.of(error).kind.name});
    emit(
      SocialAuthState(
        status: SocialAuthStatus.failed,
        activeProvider: provider,
        error: SocialAuthError.unknown,
      ),
    );
  }

  void clearError() {
    if (state.status != SocialAuthStatus.failed) return;
    emit(const SocialAuthState());
  }

  void acknowledgeCollision() {
    if (state.status != SocialAuthStatus.collision) return;
    emit(const SocialAuthState());
  }
}
