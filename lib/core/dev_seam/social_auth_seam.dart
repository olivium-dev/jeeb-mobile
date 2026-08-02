import 'package:flutter/foundation.dart';

import '../../features/auth/social/social_auth_error.dart';
import '../../features/auth/social/social_auth_service.dart';
import '../../features/auth/social/social_auth_token.dart';
import '../../features/auth/social/social_provider.dart';
import 'dev_seam.dart';

/// DEBUG-ONLY: deterministic social results (62_SEAM_HARNESS.md, JM-018/JM-019).
/// Hard short-circuit (not mock tweak): mock only accepts {google,apple}, no facebook; derives new recentlyCreated per idToken.
/// facebook_no_phone: no phone on file (forces phone-OTP). collision_409: 409 email_collision (routed to sheet, not error banner).
class SocialAuthSeam {
  SocialAuthSeam._();

  static const String facebookNoPhone = 'facebook_no_phone';

  static const String collision409 = 'collision_409';

  static const SocialAuthSeamResolver resolver = _resolve;

  static const String _seamUserId = 'user-social-seam';

  static SocialAuthResult? _resolve(SocialProvider provider) {
    if (!kDebugMode) return null;
    final variant = DevSeam.current.socialLogin;
    switch (variant) {
      case facebookNoPhone:
        // No phone on file forces phone-OTP.
        return const SocialAuthSuccess(
          SocialAuthSession(
            userId: _seamUserId,
            authToken: 'mock-social-access-$_seamUserId',
            refreshToken: 'mock-social-refresh-$_seamUserId',
            recentlyCreated: true,
          ),
        );
      case collision409:
        // 409 collision: routed (NOT error banner) to sheet.
        return const SocialAuthFailure(SocialAuthError.collision);
      default:
        return null;
    }
  }
}
