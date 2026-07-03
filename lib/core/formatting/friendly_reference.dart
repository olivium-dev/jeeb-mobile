/// Human-facing reference formatting for opaque server identifiers.
///
/// The jeeb-gateway keys requests/deliveries/orders on UUIDs
/// (`9acb579d-1c2e-4f...`) and mints synthetic account handles
/// (`jeeb-e1a35ea8a520`) and internal emails
/// (`phone-only+<hash>@jeeb.internal`). None of those are user content — the
/// sprint-009 UX audit (§T5) graded every screen that renders one D or F
/// because a raw UUID/handle is meaningless to the person reading it.
///
/// This module is the single source of truth for turning such an identifier
/// into something a human can read out loud: a short, stable, uppercase
/// reference (`#A1B2C3`) for display, plus a predicate that recognizes an
/// internal handle so name/greeting surfaces can fall back to a friendly
/// generic instead of leaking `jeeb-<hash>`.
library;

/// Number of trailing identifier characters kept in a short reference.
///
/// Six hex/alnum characters is enough to be visually distinct in a list while
/// staying glanceable and speakable ("reference A1B2C3"). It is derived from
/// the END of the id because UUID entropy is uniformly distributed and the tail
/// avoids the low-entropy version/variant nibbles some ids carry up front.
const int _shortRefLength = 6;

/// Prefixes that mark an id as ALREADY a human order reference. When an id
/// arrives pre-formatted (`ORD-23470`, `REQ-001`, `JB-1042`, `#A1B2C3`) it is
/// passed through untouched rather than being re-shortened into nonsense.
const List<String> _humanReferencePrefixes = <String>[
  'ORD-',
  'REQ-',
  'JB-',
  '#',
];

/// Matches a synthetic jeeb account handle, e.g. `jeeb-e1a35ea8a520`.
/// Case-insensitive; the hash segment is 6+ hex chars.
final RegExp _internalHandle = RegExp(
  r'^jeeb-[0-9a-f]{6,}$',
  caseSensitive: false,
);

/// Matches an internal synthetic email, e.g.
/// `phone-only+cb39e21c...@jeeb.internal`.
final RegExp _internalEmail = RegExp(r'@jeeb\.internal$', caseSensitive: false);

/// Matches a canonical 8-4-4-4-12 UUID (any version).
final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Turns an opaque identifier into a short, human-readable reference label.
///
/// Rules, in order:
///   1. `null`/blank → [fallback] (default `#—`) so a card never renders an
///      empty title.
///   2. Already a human reference (`ORD-…`, `JB-…`, `#…`) → returned verbatim
///      (trimmed). We never re-shorten a ref that a human already reads.
///   3. Anything else → the last [_shortRefLength] alphanumeric characters,
///      uppercased, behind [prefix] (default `#`), e.g.
///      `9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6` → `#CC42E6`.
///
/// The output is deterministic and stable for a given id, so it is safe to use
/// as a display key. It is NOT reversible and must never be sent back to the
/// server as an identifier — it is display-only.
String friendlyReference(
  String? id, {
  String prefix = '#',
  String fallback = '#—',
}) {
  final trimmed = id?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;

  for (final human in _humanReferencePrefixes) {
    if (trimmed.toUpperCase().startsWith(human.toUpperCase())) return trimmed;
  }

  final alnum = trimmed.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  if (alnum.isEmpty) return fallback;

  final tail = alnum.length <= _shortRefLength
      ? alnum
      : alnum.substring(alnum.length - _shortRefLength);
  return '$prefix${tail.toUpperCase()}';
}

/// Whether [value] is an internal system identifier that must never be shown to
/// a user as their name/handle — a synthetic jeeb account handle
/// (`jeeb-<hash>`), an `@jeeb.internal` email, or a bare UUID.
///
/// Greeting/profile/name surfaces call this to decide whether to render the
/// value or fall back to a friendly generic ("Welcome back") — this is the
/// content-side fix for the sprint-009 audit's "Hello, jeeb-e1a35ea8a520"
/// (§T5). Blank input returns `true` (nothing usable to show).
bool looksLikeInternalIdentifier(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return true;
  return _internalHandle.hasMatch(trimmed) ||
      _internalEmail.hasMatch(trimmed) ||
      _uuid.hasMatch(trimmed);
}

/// The user-facing name to display for [rawName], or `null` when [rawName] is
/// missing or is an internal identifier that must be suppressed.
///
/// Callers substitute a localized generic greeting when this returns `null`.
String? displayNameOrNull(String? rawName) {
  final trimmed = rawName?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (looksLikeInternalIdentifier(trimmed)) return null;
  return trimmed;
}
