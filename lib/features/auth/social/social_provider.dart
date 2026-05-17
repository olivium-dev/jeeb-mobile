/// Which native SDK produced the ID token. The gateway maps the literal
/// `provider` string to its JWKS endpoint, so values here MUST match the
/// gateway's contract.
enum SocialProvider {
  google('google'),
  apple('apple');

  const SocialProvider(this.wireName);

  /// The string sent in the POST body to /api/auth/social.
  final String wireName;
}
