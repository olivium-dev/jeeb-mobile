import 'dart:convert';

import '../../diagnostics/diag_redaction.dart';

/// Redaction for the Jeeb session-trace tool. NEVER emits a verbatim secret.
///
/// This is a hard security boundary (architecture contract §7). It reuses
/// the already-audited [DiagRedaction] primitives (header names, data keys,
/// the `tok:<fnv8>~<last4>` correlation-handle scheme, path scrubbing) and
/// adds the two things the richer session-trace capture needs on top:
///
///  * a free-form STRING pattern scanner ([redactString]) — the diag stream
///    never logs bodies, so it never needed this; we do, because api/
///    notification/interaction events carry real body/label text;
///  * whole-body redaction + size-capping for storage ([redactAndTruncate]).
///
/// All methods are total and null-safe — a redaction path must never throw
/// into a capture pipeline; a thrown exception here would be worse than the
/// leak it's trying to prevent (it would crash the capturer's hot path).
///
/// ## The `full` parameter (redaction strictness)
///
/// [redactBody] takes `required bool full`, wired to
/// `ObservabilityConfig.redactionEnabled` (default `true`). The HARD FLOOR —
/// sensitive-keyed values (this class's [kExtraSensitiveKeys] union
/// [DiagRedaction.kSensitiveDataKeys]) and secret-SHAPED string patterns
/// ([redactString]: JWT, `Bearer …`, opaque tokens, FCM-shaped ids) — is
/// ALWAYS applied, in both modes; a caller can never lower it by flipping the
/// toggle. `full: true` (the default) additionally masks long bare digit runs
/// (7+ digits: phone numbers, account numbers, anything OTP-adjacent) that
/// don't sit under a named sensitive key but still read as PII; `full: false`
/// skips ONLY that extra precaution, trading it for a more legible raw body
/// during local debugging. See architecture contract §7 rule 3.
abstract final class SecretRedactor {
  /// Body/data keys ALWAYS masked, in addition to
  /// [DiagRedaction.kSensitiveDataKeys] (adds the api-key family).
  static const Set<String> kExtraSensitiveKeys = {
    'apikey',
    'apisecret',
    'clientsecret',
    'authtoken',
    'sessiontoken',
  };

  /// The literal replacement token.
  static const String redacted = '<redacted>';

  /// `Bearer <token>` (any casing) — matched and replaced as ONE unit so the
  /// scheme word never lingers next to a half-redacted value.
  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9\-_.=]+',
    caseSensitive: false,
  );

  /// JWT shape: three base64url segments separated by dots
  /// (`header.payload.signature`).
  static final RegExp _jwtPattern = RegExp(
    r'\b[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b',
  );

  /// Long opaque tokens: 24+ contiguous token chars (letters/digits/`_-:`)
  /// that contain at least one digit. The digit requirement is a
  /// false-positive guard — plain English words/sentences rarely carry one —
  /// while still catching hex hashes, UUIDs-without-dashes, device/FCM
  /// tokens (which embed `:`), and API keys.
  static final RegExp _opaqueTokenPattern = RegExp(
    r'\b(?=[A-Za-z0-9_\-:]*\d)[A-Za-z0-9_\-:]{24,}\b',
  );

  /// Extra `full`-mode precaution: bare runs of 7+ digits (phone numbers,
  /// account numbers) that aren't behind a named sensitive key.
  static final RegExp _longDigitRun = RegExp(r'\d{7,}');

  /// Redacts secret-SHAPED spans out of a free-form string (a body value, a
  /// Semantics label, a notification title/body). Replaces each MATCH with
  /// [redacted]. This is the hard floor — it runs regardless of the
  /// `redactionEnabled` toggle everywhere it's called from this class.
  static String redactString(String input) {
    if (input.isEmpty) return input;
    var out = input.replaceAll(_bearerPattern, redacted);
    out = out.replaceAll(_jwtPattern, redacted);
    out = out.replaceAll(_opaqueTokenPattern, redacted);
    return out;
  }

  /// Redacts a headers map → correlation handles for sensitive names
  /// (delegates [DiagRedaction.redactHeaders]). Used for req/resp headers.
  static Map<String, Object?> redactHeaders(Map<String, Object?> headers) =>
      DiagRedaction.redactHeaders(headers);

  /// Recursively redacts a body value (Map/List/String/scalar): sensitive
  /// keys reduce to a correlation handle; every String leaf is pattern-
  /// scanned via [redactString]; maps and lists recurse (a list-of-maps
  /// roster is fully scrubbed). See the class doc for what [full] toggles.
  static Object? redactBody(Object? body, {required bool full}) =>
      _redactValue(body, full);

  /// Redacts + truncates a body for storage: [redactBody] then caps the
  /// post-`jsonEncode` UTF-8 size to [maxBytes], collapsing an oversized body
  /// to a `'<truncated N bytes>'` marker. Returns the storable Object?.
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

  /// Redacts a human label/free string with the hard floor always applied
  /// (used for Semantics labels + notification title/body).
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

  /// True when [key] is sensitive per [DiagRedaction.kSensitiveDataKeys] or
  /// this class's [kExtraSensitiveKeys] (case/underscore/dash-insensitive).
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
      // Not JSON-encodable (shouldn't happen post-redaction) — best-effort:
      // let the caller keep the value; the writer's own jsonEncode will
      // surface any real problem without this helper throwing into it.
      return null;
    }
  }
}
