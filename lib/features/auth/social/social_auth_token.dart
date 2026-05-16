/// JWT bundle returned by `POST /api/auth/social`.
class SocialAuthSession {
  const SocialAuthSession({
    required this.userId,
    required this.authToken,
    required this.refreshToken,
    required this.recentlyCreated,
  });

  final String userId;
  final String authToken;
  final String refreshToken;

  /// True when the gateway created the user during this call. The screen
  /// layer uses this to decide whether to push the "Link your phone" flow.
  final bool recentlyCreated;
}
