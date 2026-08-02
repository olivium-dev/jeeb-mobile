import 'package:equatable/equatable.dart';

import 'social_auth_error.dart';
import 'social_auth_token.dart';
import 'social_provider.dart';

enum SocialAuthStatus {
  idle,
  // Native sheet is open / exchanging ID token with gateway.
  inProgress,
  // Gateway returned JWT bundle and persisted it.
  authenticated,
  // Gateway returned 409 email_collision (D22, JM-019): email already registered.
  // Routes to social-collision-prompt sheet; NOT a failure banner.
  collision,
  // Flow ended with non-cancellation, non-collision failure.
  failed,
}

class SocialAuthState extends Equatable {
  const SocialAuthState({
    this.status = SocialAuthStatus.idle,
    this.activeProvider,
    this.error,
    this.session,
  });

  final SocialAuthStatus status;

  // Provider whose flow is in flight or just finished; null only when idle.
  final SocialProvider? activeProvider;

  final SocialAuthError? error;

  final SocialAuthSession? session;

  bool get isBusy => status == SocialAuthStatus.inProgress;

  bool isBusyFor(SocialProvider provider) =>
      isBusy && activeProvider == provider;

  // G8: authenticated social user with no phone must complete phone-OTP step (JM-009)
  // before landing home. False once phone on file or while not authenticated.
  bool get requiresPhoneVerification =>
      status == SocialAuthStatus.authenticated &&
      session != null &&
      !session!.hasPhone;

  bool get isCollision => status == SocialAuthStatus.collision;

  SocialAuthState copyWith({
    SocialAuthStatus? status,
    SocialProvider? activeProvider,
    Object? error = _sentinel,
    Object? session = _sentinel,
  }) {
    return SocialAuthState(
      status: status ?? this.status,
      activeProvider: activeProvider ?? this.activeProvider,
      error: identical(error, _sentinel)
          ? this.error
          : error as SocialAuthError?,
      session: identical(session, _sentinel)
          ? this.session
          : session as SocialAuthSession?,
    );
  }

  @override
  List<Object?> get props => [status, activeProvider, error, session?.userId];
}

const Object _sentinel = Object();
