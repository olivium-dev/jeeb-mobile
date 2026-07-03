/// Redaction primitives shared by the diagnostic event stream (the API
/// interceptor + `Diag.event`) and the security hardening that strips full
/// bearer JWTs / FCM tokens out of dev logging.
///
/// The contract is: a secret NEVER appears verbatim in any log line. What we
/// keep is a *correlation handle* — a short, stable, non-reversible fingerprint
/// plus the last 4 chars — so a QA/agent run can still tell "this is the same
/// token across these two lines" without the token itself ever hitting logcat.
///
/// The fingerprint is a 32-bit FNV-1a hash rendered as 8 hex chars. It is NOT a
/// cryptographic hash and is not meant to be — it exists purely so two
/// occurrences of the same token collide to the same handle. Choosing FNV-1a
/// over `package:crypto`'s SHA-256 keeps this module dependency-free and its
/// output deterministic across platforms.
library;

/// Header names whose values are secrets and must never be logged.
const Set<String> kSensitiveHeaderNames = {
  'authorization',
  'proxy-authorization',
  'x-api-key',
  'x-auth-token',
  'cookie',
  'set-cookie',
};

/// Data-map / body keys whose values are secrets and must never be logged.
const Set<String> kSensitiveDataKeys = {
  'authorization',
  'token',
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
  // G4: the delivery hand-over code. It is the customer's own credential (not
  // a secret from them) but it gates the physical hand-off, so it must never
  // reach logcat. Normalised key — matches `handoverCode` / `handover_code`.
  'handovercode',
  'otpcode',
  'deliverycode',
};

/// Redaction helpers. All methods are total and null-safe — a redaction path
/// must never throw into a request/log pipeline.
abstract final class DiagRedaction {
  static const String _nullHandle = 'tok:∅';

  /// Turns a secret into a non-reversible correlation handle of the form
  /// `tok:<fnv8>~<last4>`. Returns [_nullHandle] for null/empty input. Never
  /// returns any substring of [secret] other than its final 4 chars — and for
  /// SHORT secrets (≤ [_minLengthForTail] chars, e.g. a 4-digit handover OTP,
  /// where "the last 4 chars" IS the whole secret) the tail is omitted
  /// entirely: the handle is hash-only (`tok:<fnv8>`), G4 diag-redaction rule.
  static String redactToken(String? secret) {
    if (secret == null || secret.isEmpty) return _nullHandle;
    if (secret.length < _minLengthForTail) return 'tok:${_fnv1a8(secret)}';
    final last4 = secret.substring(secret.length - 4);
    return 'tok:${_fnv1a8(secret)}~$last4';
  }

  /// Minimum secret length before the correlation tail (`~<last4>`) is
  /// appended. Below this, 4 trailing chars reveal ≥ a third of the secret —
  /// for a 4–8 char OTP/PIN that is effectively the secret itself.
  static const int _minLengthForTail = 12;

  /// True when [name] (case-insensitively) is a secret-bearing header.
  static bool isSensitiveHeader(String name) =>
      kSensitiveHeaderNames.contains(name.toLowerCase());

  /// True when [key] (case-insensitively, ignoring `_`/`-`) is a secret key.
  static bool isSensitiveKey(String key) =>
      kSensitiveDataKeys.contains(_normalizeKey(key));

  /// Returns a copy of [headers] with every sensitive value replaced by a
  /// correlation handle. Non-sensitive headers pass through untouched.
  static Map<String, Object?> redactHeaders(Map<String, Object?> headers) {
    final out = <String, Object?>{};
    headers.forEach((key, value) {
      out[key] = isSensitiveHeader(key)
          ? redactToken(value?.toString())
          : value;
    });
    return out;
  }

  /// Returns a copy of [data] with every sensitive value replaced by a
  /// correlation handle (recursing into nested maps). Used as a defensive
  /// backstop on `Diag.event` payloads so a caller mistake can't leak a token.
  static Map<String, Object?> scrubMap(Map<String, Object?> data) {
    final out = <String, Object?>{};
    data.forEach((key, value) {
      if (isSensitiveKey(key)) {
        out[key] = redactToken(value?.toString());
      } else if (value is Map<String, Object?>) {
        out[key] = scrubMap(value);
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  /// Strips the query string from a URI/path, returning only the path segment.
  /// Query strings can carry keys/tokens, so the diagnostic stream logs the
  /// path pattern only. Total: falls back to the raw string minus any `?tail`.
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

  /// 32-bit FNV-1a over the UTF-16 code units of [input], rendered as 8 hex
  /// chars. Stable and dependency-free (see the library doc for the rationale).
  static String _fnv1a8(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
