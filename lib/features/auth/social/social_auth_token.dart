/// JWT bundle returned by `POST /v1/auth/social` (social shape: `authToken`,
/// not `accessToken` — 42_GUARDRAILS_MOCK §"W-1 FLOOR").
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

  /// True when the gateway created the user during this call. The screen
  /// layer uses this to decide whether to push the "Link your phone" flow.
  final bool recentlyCreated;

  /// The phone on file for this account, if any. The social bundle does NOT
  /// guarantee a phone — a first-time social sign-in (or the
  /// `facebook_no_phone` seam) returns no phone. JM-018/G8: when there is no
  /// phone on file the social flow MUST route to phone-OTP verification before
  /// landing home, never straight home. Normalised so `''` → `null`.
  final String? phone;

  /// G8 gate: true only when a usable phone is already on file. When false the
  /// account still needs the phone-OTP verification step (JM-009).
  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
}
