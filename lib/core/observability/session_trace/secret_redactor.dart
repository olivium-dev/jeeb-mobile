import 'dart:convert';

import '../../diagnostics/diag_redaction.dart';

abstract final class SecretRedactor {
  static const Set<String> kExtraSensitiveKeys = {
    'apikey',
    'apisecret',
    'clientsecret',
    'authtoken',
    'sessiontoken',
  };

  static const String redacted = '<redacted>';

  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9\-_.=]+',
    caseSensitive: false,
  );

  static final RegExp _jwtPattern = RegExp(
    r'\b[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b',
  );

  static final RegExp _opaqueTokenPattern = RegExp(
    r'\b(?=[A-Za-z0-9_\-:]*\d)[A-Za-z0-9_\-:]{24,}\b',
  );

  static final RegExp _longDigitRun = RegExp(r'\d{7,}');

  static String redactString(String input) {
    if (input.isEmpty) return input;
    var out = input.replaceAll(_bearerPattern, redacted);
    out = out.replaceAll(_jwtPattern, redacted);
    out = out.replaceAll(_opaqueTokenPattern, redacted);
    return out;
  }

  static Map<String, Object?> redactHeaders(Map<String, Object?> headers) =>
      DiagRedaction.redactHeaders(headers);

  static Object? redactBody(Object? body, {required bool full}) =>
      _redactValue(body, full);

  static Object? redactAndTruncate(
    Object? body, {
    required bool full,
    required int maxBytes,
  }) {
    final redactedBody = redactBody(body, full: full);
    if (redactedBody == null) return null;
    final byteLength = _encodedByteLength(redactedBody);
    if (byteLength == null || byteLength <= maxBytes) return redactedBody;
    return '<truncated $byteLength bytes>';
  }

  static String? redactLabel(String? label) =>
      label == null ? null : redactString(label);

  static Object? _redactValue(Object? value, bool full) {
    if (value == null) return null;
    if (value is Map<String, Object?>) return _redactMap(value, full);
    if (value is Map) {
      return _redactMap(value.map((k, v) => MapEntry(k.toString(), v)), full);
    }
    if (value is List) {
      return value.map((e) => _redactValue(e, full)).toList();
    }
    if (value is String) return _redactStringValue(value, full);
    return value;
  }

  static Map<String, Object?> _redactMap(
    Map<String, Object?> map,
    bool full,
  ) {
    final out = <String, Object?>{};
    map.forEach((key, value) {
      out[key] = isSensitiveKey(key)
          ? DiagRedaction.redactToken(value?.toString())
          : _redactValue(value, full);
    });
    return out;
  }

  static String _redactStringValue(String value, bool full) {
    final scanned = redactString(value);
    if (!full) return scanned;
    return scanned.replaceAll(_longDigitRun, redacted);
  }

  static bool isSensitiveKey(String key) {
    if (DiagRedaction.isSensitiveKey(key)) return true;
    return kExtraSensitiveKeys.contains(_normalizeKey(key));
  }

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll('_', '').replaceAll('-', '');

  static int? _encodedByteLength(Object? value) {
    try {
      return utf8.encode(jsonEncode(value)).length;
    } catch (_) {
      return null;
    }
  }
}
