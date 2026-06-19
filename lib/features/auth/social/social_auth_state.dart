import 'package:equatable/equatable.dart';

import 'social_auth_error.dart';
import 'social_auth_token.dart';
import 'social_provider.dart';

enum SocialAuthStatus {
  idle,

  /// A native sheet is open / we're exchanging the ID token with the gateway.
  inProgress,

  /// Gateway returned the JWT bundle and we've persisted it. The screen reads
  /// [SocialAuthState.session] / [SocialAuthState.requiresPhoneVerification]
  /// (G8) to decide between landing home and pushing the phone-OTP step.
  authenticated,

  /// Gateway returned 409 `email_collision` (D22, JM-019): the social email is
  /// already registered another way. The screen routes to the
  /// `social-collision-prompt` sheet — this is NOT a failure banner.
  collision,

  /// The flow ended with a (non-cancellation, non-collision) failure.
  failed,
}

class SocialAuthState extends Equatable {
  const SocialAuthState({
    this.status = SocialAuthStatus.idle,
    this.activeProvider,
    this.error,
    this.session,
  });

  /// High-level UI state. Buttons render their pending spinner off
  /// [status]==inProgress + matching [activeProvider].
  final SocialAuthStatus status;

  /// The provider whose flow is in flight (or just finished). `null` only
  /// when [status] is idle.
  final SocialProvider? activeProvider;

  /// Non-null on [SocialAuthStatus.failed].
  final SocialAuthError? error;

  /// Non-null on [SocialAuthStatus.authenticated]. The screen reads this to
  /// decide whether to push the "Link your phone" follow-up.
  final SocialAuthSession? session;

  bool get isBusy => status == SocialAuthStatus.inProgress;

  bool isBusyFor(SocialProvider provider) =>
      isBusy && activeProvider == provider;

  /// G8: an authenticated social user with no phone on file must complete the
  /// phone-OTP verification step (JM-009) before landing home. False once a
  /// phone is on file (or while not authenticated).
  bool get requiresPhoneVerification =>
      status == SocialAuthStatus.authenticated &&
      session != null &&
      !session!.hasPhone;

  /// True on a 409 collision (D22): the screen pushes the collision sheet.
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
