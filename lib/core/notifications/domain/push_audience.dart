library;

const String kAudienceRoleJeeber = 'jeeber';

const String kAudienceRoleClient = 'client';

String? _canonicalRoleToken(String? raw) {
  if (raw == null) return null;
  final token = raw.trim().toLowerCase();
  if (token.isEmpty) return null;
  switch (token) {
    case 'driver':
    case 'jeeber':
    case 'jeeb_jeeber':
    case 'jeebers':
      return kAudienceRoleJeeber;
    case 'customer':
    case 'client':
    case 'jeeb_client':
    case 'clients':
      return kAudienceRoleClient;
    default:
      return null;
  }
}

String? canonicalAudienceRole(Map<String, String> data) {
  final direct = _canonicalRoleToken(data['audience_role']);
  if (direct != null) return direct;
  final camel = _canonicalRoleToken(data['audienceRole']);
  if (camel != null) return camel;
  return _canonicalRoleToken(data['audience']);
}

/// Session roles for the push-audience gate, resolved from the server
/// `available_roles` and the role the session is actively operating as.
///
/// Returns the EMPTY set when [availableRoles] carries nothing usable. Empty is
/// the "roles unknown" signal [isPushAudienceMatch] fails open on, so a push
/// that arrives before getMe lands — or while it is degraded — is delivered
/// rather than classified against a role the session never claimed. Callers
/// must not substitute a placeholder role here: doing so turns "unknown" into
/// "known and not this audience" and silently drops the push (D2).
Set<String> sessionPushRoles({
  required Iterable<String> availableRoles,
  required String activeRole,
}) {
  final resolved = availableRoles
      .map((role) => role.trim())
      .where((role) => role.isNotEmpty)
      .toSet();
  if (resolved.isEmpty) return const <String>{};
  // The session demonstrably holds the role it is operating as, so a degraded
  // available_roles must never narrow the gate below it.
  final active = activeRole.trim();
  return active.isEmpty ? resolved : <String>{...resolved, active};
}

bool isPushAudienceMatch(Map<String, String> data, Set<String> localRoles) {
  final audience = canonicalAudienceRole(data);
  if (audience == null) return true;
  if (localRoles.isEmpty) return true;
  final normalisedLocalRoles = localRoles
      .map(_canonicalRoleToken)
      .whereType<String>()
      .toSet();
  return normalisedLocalRoles.contains(audience);
}
