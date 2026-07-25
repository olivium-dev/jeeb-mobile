// PURE Dart. No Flutter / Firebase imports here (40_GUARDRAILS_ARCH §1 layer
// rules) — this is the domain contract; the handler wiring lives in
// `application/push_notification_handler.dart` and the role sourcing lives
// in `app/app.dart`.

/// P1 (b01-20260725) defence-in-depth: client-side audience guard so a
/// device never SHOWS a `new_request` push it should not receive
/// (non-jeebers, or — once the gateway leak is closed — the initiator's own
/// device). The AUTHORITATIVE fix is gateway-side per-user, availability-
/// filtered fan-out (see `docs/batches/b01-20260725/plans/P1.md`); this is
/// strictly a safety net and can NEVER suppress a background-isolate OS tray
/// banner (FCM renders that before Dart runs) — it only stops
/// foreground banner/badge/local-inbox pollution.
library;

/// The 'jeeber' audience token, mirroring `Roles.Jeeber` = `"driver"` /
/// contract `"jeeber"` / legacy topic `"jeeb_jeeber"` on the gateway
/// (`JeebPushTopicMap.TopicForRole`, `JeebRoleTranslator`).
const String kAudienceRoleJeeber = 'jeeber';

/// The 'client' audience token, mirroring `Roles.Client` = `"customer"` /
/// contract `"client"` / legacy topic `"jeeb_client"`.
const String kAudienceRoleClient = 'client';

/// Canonicalises any of the wire vocabularies the gateway may stamp on a
/// push into `'jeeber'` | `'client'` | `null` (unknown / absent).
///
/// Accepts (case-insensitive):
/// - opaque contract role: `driver` → jeeber, `customer` → client
/// - contract token: `jeeber`, `client`
/// - legacy topic name: `jeeb_jeeber`, `jeeb_client`
/// - plural audience form: `jeebers`, `clients`
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

/// Resolves the audience role a push payload was targeted at, or `null` when
/// the payload carries no recognisable audience hint (e.g. a chat/offer push
/// that isn't role-scoped, or an unknown vocabulary token).
///
/// Read order: `audience_role`, then `audienceRole`, then `audience`
/// (`"jeebers"`/`"clients"` plural forms accepted from that last key).
String? canonicalAudienceRole(Map<String, String> data) {
  final direct = _canonicalRoleToken(data['audience_role']);
  if (direct != null) return direct;
  final camel = _canonicalRoleToken(data['audienceRole']);
  if (camel != null) return camel;
  return _canonicalRoleToken(data['audience']);
}

/// Whether this device's session should show a push carrying [data], given
/// the roles [localRoles] this session currently holds.
///
/// FAIL-OPEN BY DESIGN: returns `true` (never suppress) when
/// - the payload has no audience hint at all,
/// - the hint is an unknown token, or
/// - [localRoles] is empty (roles not yet known — `getMe` has not landed).
///
/// Only a POSITIVE mismatch — a recognised audience role that this session's
/// (normalised) role set does not contain — suppresses the push.
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
