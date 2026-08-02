library;

const int _shortRefLength = 6;

const List<String> _humanReferencePrefixes = <String>[
  'ORD-',
  'REQ-',
  'JB-',
  '#',
];

final RegExp _internalHandle = RegExp(
  r'^jeeb-[0-9a-f]{6,}$',
  caseSensitive: false,
);

final RegExp _internalEmail = RegExp(r'@jeeb\.internal$', caseSensitive: false);

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

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

bool looksLikeInternalIdentifier(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return true;
  return _internalHandle.hasMatch(trimmed) ||
      _internalEmail.hasMatch(trimmed) ||
      _uuid.hasMatch(trimmed);
}

String? displayNameOrNull(String? rawName) {
  final trimmed = rawName?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (looksLikeInternalIdentifier(trimmed)) return null;
  return trimmed;
}
