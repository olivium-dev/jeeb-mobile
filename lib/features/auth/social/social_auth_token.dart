/// JWT bundle from POST /v1/auth/social (uses authToken, not accessToken).
class SocialAuthSession {
  const SocialAuthSession({
    required this.userId,
    required this.authToken,
    required this.refreshToken,
    required this.recentlyCreated,
    this.phone,
  });

  final String userId;
  final String authToken;
  final String refreshToken;

  /// True if gateway created user during this call; screen uses to decide
  /// whether to push "Link your phone" flow.
  final bool recentlyCreated;

  /// Phone on file (null if not provided; social doesn't guarantee phone).
  /// First-time social sign-in or facebook_no_phone seam returns null.
  /// When null, must route through phone-OTP verification before home.
  /// Normalised: '' → null.
  final String? phone;

  /// G8 gate: true only when usable phone on file (account still needs
  /// phone-OTP verification when false).
  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
}
