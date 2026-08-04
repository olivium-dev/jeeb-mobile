/// Which native SDK initiated the social sign-in. Values here must match the
/// gateway's social platform contract.
enum SocialProvider {
  google('google'),
  facebook('facebook'),
  apple('apple');

  const SocialProvider(this.wireName);

  /// The string sent in the POST body to `/v1/auth/social`.
  final String wireName;
}
