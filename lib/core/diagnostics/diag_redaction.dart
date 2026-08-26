library;

const Set<String> kSensitiveHeaderNames = {
  'authorization',
  'proxy-authorization',
  'x-api-key',
  'x-auth-token',
  'cookie',
  'set-cookie',
};

const Set<String> kSensitiveDataKeys = {
  'authorization',
  'token',
  'ticket',
  'membershipticket',
  'accesstoken',
  'refreshtoken',
  'idtoken',
  'fcmtoken',
  'devicetoken',
  'password',
  'passcode',
  'secret',
  'otp',
  'jwt',
  'bearer',
  'handovercode',
  'otpcode',
  'deliverycode',
  'idnumber',
  'nationalid',
};

abstract final class DiagRedaction {
  static const String _nullHandle = 'tok:∅';

  static const Set<String> _bodySuppressedPaths = {
    '/v1/auth/otp/request',
    '/v1/auth/otp/verify',
    '/auth/otp/request',
    '/auth/otp/verify',
  };

  static String redactToken(String? secret) {
    if (secret == null || secret.isEmpty) return _nullHandle;
    if (secret.length < _minLengthForTail) return 'tok:${_fnv1a8(secret)}';
    final last4 = secret.substring(secret.length - 4);
    return 'tok:${_fnv1a8(secret)}~$last4';
  }

  static const int _minLengthForTail = 12;

  static bool isSensitiveHeader(String name) =>
      kSensitiveHeaderNames.contains(name.toLowerCase());

  static bool isSensitiveKey(String key) =>
      kSensitiveDataKeys.contains(_normalizeKey(key));

  static bool isBodySuppressedPath(String pathOrUri) {
    final path = scrubPath(pathOrUri).toLowerCase();
    final withLeadingSlash = path.startsWith('/') ? path : '/$path';
    final normalized = withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
    return _bodySuppressedPaths.contains(normalized);
  }

  static Map<String, Object?> redactHeaders(Map<String, Object?> headers) {
    final out = <String, Object?>{};
    headers.forEach((key, value) {
      out[key] = isSensitiveHeader(key)
          ? redactToken(value?.toString())
          : value;
    });
    return out;
  }

  static Map<String, Object?> scrubMap(Map<String, Object?> data) {
    final out = <String, Object?>{};
    data.forEach((key, value) {
      if (isSensitiveKey(key)) {
        out[key] = redactToken(value?.toString());
      } else {
        out[key] = _scrubValue(value);
      }
    });
    return out;
  }

  static Object? _scrubValue(Object? value) {
    if (value is Map<String, Object?>) return scrubMap(value);
    if (value is Map) {
      return scrubMap(value.map((k, v) => MapEntry(k.toString(), v)));
    }
    if (value is List) return value.map(_scrubValue).toList();
    return value;
  }

  static String scrubPath(String pathOrUri) {
    try {
      return Uri.parse(pathOrUri).path;
    } catch (_) {
      final q = pathOrUri.indexOf('?');
      return q == -1 ? pathOrUri : pathOrUri.substring(0, q);
    }
  }

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll('_', '').replaceAll('-', '');

  static String _fnv1a8(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
