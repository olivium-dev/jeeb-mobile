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
        // JM-018/G8: authenticated either way. The screen inspects
        // [SocialAuthState.requiresPhoneVerification] (no phone on file → push
        // phone-OTP, JM-009) vs landing home — the cubit does not navigate.
        emit(SocialAuthState(
          status: SocialAuthStatus.authenticated,
          activeProvider: provider,
          session: session,
        ));
      case SocialAuthFailure(error: SocialAuthError.cancelled):
        // Silent return — the user just dismissed the sheet.
        emit(const SocialAuthState());
      case SocialAuthFailure(error: SocialAuthError.collision):
        // JM-018/JM-019 (D22): 409 email_collision is NOT an error banner — it
        // is a routed outcome to the `social-collision-prompt` sheet. Carry the
        // active provider so the sheet can name it if needed.
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

  /// Dismiss a failed-state error banner so the buttons are tappable again.
  void clearError() {
    if (state.status != SocialAuthStatus.failed) return;
    emit(const SocialAuthState());
  }

  /// Reset after the collision sheet (JM-019) has been presented so the social
  /// buttons are tappable again and the listener does not re-fire the sheet on
  /// the next rebuild. No-op unless the cubit is in the collision state.
  void acknowledgeCollision() {
    if (state.status != SocialAuthStatus.collision) return;
    emit(const SocialAuthState());
  }
}
