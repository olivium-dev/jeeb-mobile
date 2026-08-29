import 'dart:convert';

import '../../diagnostics/diag_redaction.dart';

abstract final class SecretRedactor {
  static const Set<String> kSensitiveKeys = {
    'apikey',
    'apisecret',
    'clientsecret',
    'authtoken',
    'sessiontoken',
    'phone',
    'phonenumber',
    'mobile',
    'mobilenumber',
    'email',
    'emailaddress',
    'address',
    'street',
    'streetaddress',
    'addressline1',
    'addressline2',
    'postalcode',
    'postcode',
    'latitude',
    'longitude',
    'lat',
    'lon',
    'lng',
    'coordinates',
    'location',
    'gps',
    'message',
    'body',
    'text',
    'content',
    'chat',
    'chattext',
    'freetext',
    'note',
    'notes',
    'comment',
    'comments',
    'description',
    'title',
    'transcription',
    'caption',
    'label',
    'building',
    'floorapt',
    'deliverynotes',
    'name',
    'username',
    'targetlabel',
    'firstname',
    'lastname',
    'fullname',
    'customername',
  };

  static const Set<String> _sensitiveKeyFragments = {
    'authorization',
    'password',
    'passcode',
    'secret',
    'token',
    'cookie',
    'otp',
    'phone',
    'email',
    'address',
    'latitude',
    'longitude',
    'coordinate',
    'location',
    'gps',
    'chat',
    'transcript',
    'caption',
    'building',
    'floorapt',
    'deliverynote',
    'username',
    'targetlabel',
    'firstname',
    'lastname',
    'fullname',
    'customername',
  };

  /// String-valued fields are denied by default. These are the deliberately
  /// small, audited exceptions needed to diagnose a trace without retaining
  /// user-authored prose.
  static const Set<String> _safeStringKeys = {
    'action',
    'route',
    'prev',
    'm',
    'method',
    'path',
    'reqid',
    'screen',
    'errortype',
    'channel',
    'mode',
    'messageid',
    'category',
    'deeplink',
    'gesture',
    'targetid',
    'valuepreview',
    'status',
    'state',
    'kind',
    'outcome',
    'result',
    'type',
    't',
    'sessionid',
    'seq',
    'ts',
    'role',
    'os',
    'appversion',
    'buildsha',
    'contenttype',
    'contentlength',
    'accept',
    'xrequestid',
    'xcorrelationid',
  };

  static const Set<String> _safeHeaderNames = {
    'contenttype',
    'contentlength',
    'accept',
    'xrequestid',
    'xcorrelationid',
  };

  /// Audited endpoint vocabulary that is safe to retain in a network trace.
  /// Every other path segment is treated as a potentially user-controlled ID,
  /// object reference, filename, capability, or piece of PII.
  static const Set<String> _safeNetworkPathSegments = {
    '__mock',
    'accept',
    'acknowledge',
    'active',
    'api',
    'assets',
    'auth',
    'auth-service',
    'availability',
    'cancel',
    'channels',
    'chat',
    'chat-service',
    'cdn',
    'compliment-service',
    'content',
    'contract-signing-service',
    'contract-template',
    'contracts',
    'conversations',
    'decline',
    'deliveries',
    'delivery',
    'delivery-service',
    'device',
    'devices',
    'disputes',
    'earnings',
    'escalate',
    'export',
    'feed',
    'feedback',
    'feedback-service',
    'firebase-token',
    'form-builder-service',
    'form-schema',
    'geolocation-service',
    'goods-cost',
    'handover',
    'handover-code',
    'jeeb',
    'jeeb-chat',
    'jeebers',
    'kyc',
    'language',
    'ledger',
    'location',
    'login',
    'logout',
    'matching',
    'me',
    'messages',
    'moderation',
    'notification-service',
    'notifications',
    'offer-service',
    'offers',
    'otp',
    'password',
    'pending',
    'preferences',
    'profile',
    'prohibited-items',
    'push-notification',
    'pushnotification',
    'ratings',
    'read',
    'realtime',
    'realtime-comunication-service',
    'recovery',
    'refresh',
    'register',
    'reply',
    'report',
    'request',
    'requests',
    'reset',
    'reviews',
    'role',
    'run',
    'saved-locations',
    'score-taking-service',
    'seed',
    'send',
    'set-password',
    'sign',
    'signup',
    'since',
    'social',
    'statements',
    'status',
    'submit',
    'super-login',
    'support',
    'support-service',
    'switch',
    'templates',
    'tickets',
    'tiers',
    'tracking',
    'transcribe',
    'transition',
    'unregister',
    'update',
    'user',
    'user-id-login',
    'user-management',
    'userpreferences',
    'users',
    'v1',
    'v2',
    'verify',
    'voice',
    'voice-transcription-service',
    'wallet',
    'wallet-service',
    'waiting',
  };

  static const Set<String> _safeNetworkTemplateSegments = {
    ':conversationId',
    ':deliveryId',
    ':disputeId',
    ':id',
    ':jeeberId',
    ':offerId',
    ':prefKey',
    ':requestId',
    ':reviewId',
    ':ticketId',
    ':userId',
  };

  static const String externalUploadPath = '/external-upload';
  static const String redactedPathSegment = ':value';

  static const Set<String> _safeNumericKeys = {
    'v',
    'seq',
    'status',
    'ms',
    'dx',
    'dy',
    'count',
    'bytes',
    'contentlength',
    'xobsrequestbytes',
    'xobsresponsebytes',
    'maxsessionbytes',
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

  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  static final RegExp _phonePattern = RegExp(r'\+?\d(?:[\s().\-]*\d){6,}');

  static final RegExp _longDigitRun = RegExp(r'\d{7,}');

  static final RegExp _safeCodePattern = RegExp(
    r'^(?!.*\d{4,})[A-Za-z][A-Za-z0-9_.:-]{0,95}$',
  );

  static final RegExp _safeIdentifierPattern = RegExp(
    r'^(?!.*\d{4,})(?=.*[A-Za-z])[A-Za-z0-9_.:/-]{1,160}$',
  );

  static final RegExp _otpDigitRun = RegExp(r'\d{4,}');

  static final RegExp _safeMimePattern = RegExp(
    r'^[A-Za-z0-9.+-]+/[A-Za-z0-9.+-]+$',
  );

  static final RegExp _safeLengthPreviewPattern = RegExp(r'^\d+ chars$');

  static final RegExp _safeVersionPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9.+_-]{0,63}$',
  );

  static final RegExp _safeSessionIdPattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-\d{3}Z-'
    r'[A-Za-z][A-Za-z0-9_-]{0,31}$',
  );

  static String redactString(String input) {
    if (input.isEmpty) return input;
    var out = input.replaceAll(_bearerPattern, redacted);
    out = out.replaceAll(_jwtPattern, redacted);
    out = out.replaceAll(_opaqueTokenPattern, redacted);
    out = out.replaceAll(_emailPattern, redacted);
    out = out.replaceAll(_phonePattern, redacted);
    out = out.replaceAll(_longDigitRun, redacted);
    return out;
  }

  static Map<String, Object?> redactHeaders(Map<String, Object?> headers) {
    final out = <String, Object?>{};
    headers.forEach((key, value) {
      final normalized = _normalizeKey(key);
      if (DiagRedaction.isSensitiveHeader(key) || isSensitiveKey(key)) {
        out[key] = redacted;
      } else if (_safeHeaderNames.contains(normalized)) {
        out[key] = _redactHeaderValue(value, normalized);
      } else {
        out[key] = redacted;
      }
    });
    return out;
  }

  /// [full] remains only for source compatibility. Both values apply the same
  /// mandatory full-redaction policy.
  static Object? redactBody(Object? body, {bool full = true}) =>
      _redactValue(body);

  /// [full] is ignored intentionally; callers cannot relax redaction.
  static Object? redactAndTruncate(
    Object? body, {
    bool full = true,
    required int maxBytes,
  }) {
    final redactedBody = redactBody(body);
    if (redactedBody == null) return null;
    final byteLength = _encodedByteLength(redactedBody);
    if (byteLength == null || byteLength <= maxBytes) return redactedBody;
    return '<truncated $byteLength bytes>';
  }

  /// User-visible labels and prose are never diagnostic-safe. Stable semantic
  /// identifiers remain available separately for interaction diagnosis.
  static String? redactLabel(String? label) {
    if (label == null || label.isEmpty) return label;
    return redacted;
  }

  static String? redactIdentifier(String? identifier) {
    if (identifier == null || identifier.isEmpty) return identifier;
    final scanned = redactString(identifier);
    if (scanned != identifier) return redacted;
    return _safeIdentifierPattern.hasMatch(identifier) ? identifier : redacted;
  }

  static String? redactPath(String? path) {
    if (path == null || path.isEmpty) return path;
    return _redactStringField('path', path);
  }

  /// Redacts app routes while retaining audited named routes such as `shell`.
  /// Network paths and deep links remain slash-only via [redactPath].
  static String? redactRoute(String? route) {
    if (route == null || route.isEmpty) return route;
    return _redactStringField('route', route);
  }

  /// Produces a diagnostic route template without retaining network
  /// capabilities or user-controlled path segments.
  ///
  /// Absolute URLs outside [baseUrl]'s origin are signed/direct uploads from
  /// the recorder's perspective. Their host and complete path are replaced by
  /// one sentinel. Relative and same-origin URLs retain only the audited
  /// endpoint vocabulary above.
  static String? redactNetworkPath(String? path, {String? baseUrl}) {
    if (path == null || path.isEmpty) return path;
    final parsed = Uri.tryParse(path);
    if (parsed == null) return '/$redactedPathSegment';
    if (parsed.hasScheme || parsed.host.isNotEmpty) {
      final base = baseUrl == null ? null : Uri.tryParse(baseUrl);
      if (!_sameOrigin(parsed, base)) return externalUploadPath;
      return _redactRelativeNetworkPath(parsed.path);
    }
    return _redactRelativeNetworkPath(parsed.path);
  }

  static Object? _redactValue(Object? value) {
    if (value == null) return null;
    if (value is Map<String, Object?>) return _redactMap(value);
    if (value is Map) {
      return _redactMap(value.map((k, v) => MapEntry(k.toString(), v)));
    }
    if (value is List) return value.map(_redactValue).toList();
    if (value is String) return _generatedMarkerOrRedacted(value);
    if (value is bool) return value;
    return redacted;
  }

  static Map<String, Object?> _redactMap(Map<String, Object?> map) {
    final out = <String, Object?>{};
    map.forEach((key, value) {
      if (isSensitiveKey(key)) {
        out[key] = redacted;
        return;
      }
      if (value is String) {
        out[key] = _redactStringField(key, value);
        return;
      }
      if (value is num) {
        out[key] = _safeNumericKeys.contains(_normalizeKey(key))
            ? value
            : redacted;
        return;
      }
      out[key] = _redactValue(value);
    });
    return out;
  }

  static Object? _redactHeaderValue(Object? value, String normalizedKey) {
    if (value is List) {
      return value
          .map((item) => _redactHeaderValue(item, normalizedKey))
          .toList();
    }
    if (value is num) {
      return normalizedKey == 'contentlength' && value >= 0 ? value : redacted;
    }
    if (value is! String) return redacted;
    final scanned = redactString(value);
    if (scanned != value) return redacted;
    return switch (normalizedKey) {
      'contenttype' ||
      'accept' => _safeMimePattern.hasMatch(value) ? value : redacted,
      'contentlength' => int.tryParse(value) == null ? redacted : value,
      'xrequestid' || 'xcorrelationid' => redactIdentifier(value),
      _ => redacted,
    };
  }

  static String _redactStringField(String key, String value) {
    if (value.isEmpty) return value;
    final marker = _generatedMarkerOrNull(value);
    if (marker != null) return marker;
    final normalized = _normalizeKey(key);
    if (!_safeStringKeys.contains(normalized)) return redacted;
    if (normalized == 'ts' && DateTime.tryParse(value) != null) return value;
    if (normalized == 'sessionid' && _safeSessionIdPattern.hasMatch(value)) {
      return value;
    }
    if (normalized == 'appversion' && _safeVersionPattern.hasMatch(value)) {
      return value;
    }
    final scanned = redactString(value);
    if (scanned != value) return redacted;
    return switch (normalized) {
      'route' || 'prev' || 'screen' =>
        ((_safeCodePattern.hasMatch(value) || value.startsWith('/')) &&
                !value.contains('?') &&
                !value.contains('#') &&
                !_otpDigitRun.hasMatch(value))
            ? value
            : redacted,
      'path' || 'deeplink' =>
        value.startsWith('/') &&
                !value.contains('?') &&
                !value.contains('#') &&
                !_otpDigitRun.hasMatch(value)
            ? value
            : redacted,
      'm' || 'method' =>
        const {
              'GET',
              'POST',
              'PUT',
              'PATCH',
              'DELETE',
              'HEAD',
              'OPTIONS',
            }.contains(value.toUpperCase())
            ? value.toUpperCase()
            : redacted,
      'sessionid' =>
        _safeSessionIdPattern.hasMatch(value) ||
                _safeCodePattern.hasMatch(value)
            ? value
            : redacted,
      'reqid' ||
      'messageid' ||
      'targetid' ||
      'buildsha' => redactIdentifier(value) ?? redacted,
      'contenttype' ||
      'accept' => _safeMimePattern.hasMatch(value) ? value : redacted,
      'contentlength' => int.tryParse(value) == null ? redacted : value,
      'valuepreview' =>
        _safeLengthPreviewPattern.hasMatch(value) ? value : redacted,
      'ts' => DateTime.tryParse(value) == null ? redacted : value,
      'appversion' => _safeVersionPattern.hasMatch(value) ? value : redacted,
      _ => _safeCodePattern.hasMatch(value) ? value : redacted,
    };
  }

  static String _generatedMarkerOrRedacted(String value) =>
      _generatedMarkerOrNull(value) ?? redacted;

  static String? _generatedMarkerOrNull(String value) {
    if (value == redacted) return redacted;
    if (RegExp(r'^<truncated \d+ bytes>$').hasMatch(value)) return value;
    if (value == '<non-serializable body>') return value;
    return null;
  }

  static bool isSensitiveKey(String key) {
    if (DiagRedaction.isSensitiveKey(key)) return true;
    final normalized = _normalizeKey(key);
    return kSensitiveKeys.contains(normalized) ||
        _sensitiveKeyFragments.any(normalized.contains);
  }

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll('_', '').replaceAll('-', '');

  static String _redactRelativeNetworkPath(String rawPath) {
    if (rawPath.isEmpty || rawPath == '/') return '/';
    final segments = Uri.tryParse(rawPath)?.pathSegments ?? const <String>[];
    if (segments.isEmpty) return '/$redactedPathSegment';
    final sanitized = segments.map((segment) {
      if (_safeNetworkTemplateSegments.contains(segment)) return segment;
      return _safeNetworkPathSegments.contains(segment.toLowerCase())
          ? segment
          : redactedPathSegment;
    });
    return '/${sanitized.join('/')}';
  }

  static bool _sameOrigin(Uri absolute, Uri? base) {
    if (base == null ||
        !absolute.hasScheme ||
        absolute.host.isEmpty ||
        !base.hasScheme ||
        base.host.isEmpty) {
      return false;
    }
    return absolute.scheme.toLowerCase() == base.scheme.toLowerCase() &&
        absolute.host.toLowerCase() == base.host.toLowerCase() &&
        _effectivePort(absolute) == _effectivePort(base);
  }

  static int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return switch (uri.scheme.toLowerCase()) {
      'http' => 80,
      'https' => 443,
      _ => -1,
    };
  }

  static int? _encodedByteLength(Object? value) {
    try {
      return utf8.encode(jsonEncode(value)).length;
    } catch (_) {
      return null;
    }
  }
}
