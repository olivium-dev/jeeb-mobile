import 'package:flutter_bloc/flutter_bloc.dart';

import 'social_auth_error.dart';
import 'social_auth_service.dart';
import 'social_auth_state.dart';
import 'social_auth_token_store.dart';
import 'social_provider.dart';

/// Owns the social sign-in flow. The screen layer calls [signInWith] when
/// the user taps a button; the cubit drives the native sheet via
/// [SocialAuthService] and persists the resulting JWT via
/// [SocialAuthTokenStore].
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

    final result = await _service.signIn(provider);

    switch (result) {
      case SocialAuthSuccess(session: final session):
        await _tokenStore.save(session);
        emit(SocialAuthState(
          status: SocialAuthStatus.authenticated,
          activeProvider: provider,
          session: session,
        ));
      case SocialAuthFailure(error: SocialAuthError.cancelled):
        // Silent return — the user just dismissed the sheet.
        emit(const SocialAuthState());
      case SocialAuthFailure(error: final error):
        emit(SocialAuthState(
          status: SocialAuthStatus.failed,
          activeProvider: provider,
          error: error,
        ));
    }
  }

  /// Dismiss a failed-state error banner so the buttons are tappable again.
  void clearError() {
    if (state.status != SocialAuthStatus.failed) return;
    emit(const SocialAuthState());
  }
}
