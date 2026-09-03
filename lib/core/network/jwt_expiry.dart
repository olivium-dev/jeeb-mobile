import 'dart:convert';

/// UTC `exp` of a JWT, or null for opaque/malformed tokens (e.g. mock-jwt-*),
/// which callers must treat as "expiry unknown", never as expired.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payloadRaw = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payloadRaw);
    if (decoded is! Map) return null;
    final exp = decoded['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt(), isUtc: true);
  } catch (_) {
    return null;
  }
}
