
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
