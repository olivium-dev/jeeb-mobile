/// Which native SDK produced the ID token. The gateway maps the literal
/// `provider` string to its JWKS endpoint, so values here MUST match the
/// gateway's contract (`provider: "google"|"apple"|"facebook"` — see the
/// verified `POST /v1/auth/social` table, 42_GUARDRAILS_MOCK §"W-1 FLOOR").
enum SocialProvider {
  google('google'),
  facebook('facebook'),
  apple('apple');

  const SocialProvider(this.wireName);

  /// The string sent in the POST body to `/v1/auth/social`.
  final String wireName;
}
