import 'dart:convert';

/// Parsed RFC 7807 `application/problem+json` body as the gateway emits it.
/// Never reads `code`, `error` or `message` — the gateway does not send them.
final class GatewayProblem {
  const GatewayProblem({
    this.type,
    this.title,
    this.detail,
    this.status,
    this.instance,
    this.traceId,
    this.errors = const <String, List<String>>{},
    this.extensions = const <String, Object?>{},
  });

  /// Returns null for anything that is not a problem document: HTML, plain
  /// strings, lists, or maps carrying none of the RFC 7807 members.
  static GatewayProblem? tryParse(Object? body) {
    final map = _asMap(body);
    if (map == null) return null;

    final type = _asString(map['type']);
    final title = _asString(map['title']);
    final detail = _asString(map['detail']);
    final status = _asInt(map['status']);
    final instance = _asString(map['instance']);
    final traceId = _asString(map['traceId']);
    final errors = _asErrors(map['errors']);
    final hasMember = type != null ||
        title != null ||
        detail != null ||
        status != null ||
        instance != null ||
        traceId != null ||
        errors.isNotEmpty;
    if (!hasMember) return null;

    final extensions = <String, Object?>{
      for (final entry in map.entries)
        if (!_reservedMembers.contains(entry.key)) entry.key: entry.value,
    };
    return GatewayProblem(
      type: type,
      title: title,
      detail: detail,
      status: status,
      instance: instance,
      traceId: traceId,
      errors: errors,
      extensions: extensions.isEmpty
          ? const <String, Object?>{}
          : Map<String, Object?>.unmodifiable(extensions),
    );
  }

  final String? type;
  final String? title;
  final String? detail;
  final int? status;
  final String? instance;
  final String? traceId;

  /// Field name → messages, from the ASP.NET `errors{}` member.
  final Map<String, List<String>> errors;

  /// Every non-reserved member, raw. Typed getters below read from it.
  final Map<String, Object?> extensions;

  /// Last path segment of a DOMAIN `type` (`…/errors/offer-already-exists`);
  /// null for `about:blank` and for the RFC links a plain 401/404 carries.
  String? get typeSuffix {
    final raw = type;
    if (raw == null || raw == _blankType) return null;
    final withoutFragment = raw.split('#').first.split('?').first;
    if (!withoutFragment.contains('/errors/')) return null;
    final segments =
        withoutFragment.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final last = segments.last;
    return last == _blankType ? null : last;
  }

  String? get reason => _string('reason');

  String? get reasonCode => _string('reasonCode');

  String? get accountStatus => _string('accountStatus');

  String? get field => _string('field');

  String? get escalationId => _string('escalationId');

  String? get upstreamCode => _string('upstreamCode');

  String? get existingCaseId => _string('existingCaseId');

  String? get currency => _string('currency');

  Duration? get retryAfter {
    final seconds = _number('retryAfter');
    if (seconds == null || seconds <= 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  int? get attemptsRemaining => _asInt(extensions['attemptsRemaining']);

  DateTime? get lockedAt {
    final raw = _string('lockedAt');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  double? get needed => _number('needed');

  double? get available => _number('available');

  /// Moderation keywords, from `matches: ["knife"]` or `matches: [{keyword}]`.
  List<String> get matches {
    final raw = extensions['matches'];
    if (raw is! List) return const <String>[];
    final out = <String>[];
    for (final item in raw) {
      if (item is String) {
        final value = item.trim();
        if (value.isNotEmpty) out.add(value);
      } else if (item is Map) {
        final keyword = _asString(item['keyword']);
        if (keyword != null) out.add(keyword);
      }
    }
    return out.isEmpty ? const <String>[] : List<String>.unmodifiable(out);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GatewayProblem &&
          other.type == type &&
          other.title == title &&
          other.detail == detail &&
          other.status == status &&
          other.instance == instance &&
          other.traceId == traceId &&
          deepJsonEquals(other.errors, errors) &&
          deepJsonEquals(other.extensions, extensions);

  @override
  int get hashCode => Object.hash(
        type,
        title,
        detail,
        status,
        instance,
        traceId,
        errors.length,
        extensions.length,
      );

  /// Diagnostics only: never renders `detail`/`title`, which can carry
  /// server prose about the caller's own payload.
  @override
  String toString() {
    final parts = <String>[
      if (typeSuffix != null) 'type: $typeSuffix',
      if (status != null) 'status: $status',
      if (traceId != null) 'traceId: $traceId',
      if (errors.isNotEmpty) 'fields: ${errors.length}',
    ];
    return 'GatewayProblem(${parts.join(', ')})';
  }

  String? _string(String key) => _asString(extensions[key]);

  double? _number(String key) => _asDouble(extensions[key]);

  static const String _blankType = 'about:blank';

  static const Set<String> _reservedMembers = <String>{
    'type',
    'title',
    'detail',
    'status',
    'instance',
    'traceId',
    'errors',
  };
}

/// Structural equality for decoded JSON values.
bool deepJsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!deepJsonEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

Map<String, Object?>? _asMap(Object? body) {
  if (body is Map) {
    return <String, Object?>{
      for (final entry in body.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
  if (body is List<int>) {
    try {
      return _asMap(utf8.decode(body));
    } on FormatException {
      return null;
    }
  }
  if (body is String) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;
    try {
      return _asMap(json.decode(trimmed));
    } on FormatException {
      return null;
    }
  }
  return null;
}

String? _asString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

Map<String, List<String>> _asErrors(Object? value) {
  if (value is! Map) return const <String, List<String>>{};
  final out = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || key.isEmpty) continue;
    final raw = entry.value;
    if (raw is String) {
      final message = raw.trim();
      if (message.isNotEmpty) out[key] = <String>[message];
    } else if (raw is List) {
      final messages = raw
          .whereType<String>()
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList(growable: false);
      if (messages.isNotEmpty) out[key] = messages;
    }
  }
  return out.isEmpty
      ? const <String, List<String>>{}
      : Map<String, List<String>>.unmodifiable(out);
}
