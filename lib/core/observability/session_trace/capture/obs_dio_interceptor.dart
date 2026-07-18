import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../diagnostics/diag_redaction.dart';
import '../model/obs_event.dart';
import '../observability.dart';
import '../observability_config.dart';
import '../secret_redactor.dart';

/// Dio [Interceptor] that captures the FULL HTTP exchange — method, URL
/// (query redacted), status, duration, redacted header/body snippets, and
/// payload byte sizes — into one [ObsApiEvent] per round-trip (architecture
/// contract §4, Module 2).
///
/// This is the richer, unified sibling of `DiagDioInterceptor` (which stays
/// untouched and keeps emitting its low-fidelity path+status+duration-only
/// `[jeeb-diag]` line). Modeled directly on its stopwatch-in-`options.extra`
/// timing + correlation-id extraction, but captures the whole exchange
/// instead of a summary:
///
///  * [onRequest] stashes the start time, a monotonic `seq`
///    ([Observability.nextSeq]) and the active `screen`
///    ([Observability.currentScreen]) into `options.extra`, then ALWAYS
///    calls `handler.next(options)` — this interceptor NEVER short-circuits
///    a request, so a disabled/compiled-out tool is behaviorally invisible.
///  * [onResponse]/[onError] build exactly ONE [ObsApiEvent] describing the
///    exchange and hand it to `Observability.instance.record(...)`, then
///    ALWAYS call `handler.next(...)` so the response/error keeps flowing to
///    the caller exactly as if this interceptor were absent.
///
/// On a `DioException` carrying an attached `response` (e.g. a 4xx/5xx the
/// gateway answered, which Dio surfaces as an error, not just a transport
/// failure/timeout) the status/headers/body are still captured from that
/// response — only a true transport failure/timeout leaves `statusCode` and
/// the response fields empty, per [ObsApiEvent.statusCode]'s contract.
///
/// ## Redaction (hard security boundary — architecture contract §7)
///
/// Every field that could carry a secret passes through [SecretRedactor] (or
/// [DiagRedaction.scrubPath] for the URL) BEFORE it is stored on the event:
///  * `requestHeaders`/`responseHeaders` — [SecretRedactor.redactHeaders];
///    Authorization/Cookie/etc. are reduced to a correlation handle, NEVER
///    the raw secret.
///  * `requestBody`/`responseBody` — only captured when
///    [ObservabilityConfig.captureApiBodies] is true, then
///    [SecretRedactor.redactAndTruncate] (sensitive keys + secret-shaped
///    string patterns are ALWAYS masked regardless of
///    [ObservabilityConfig.redactionEnabled]; an oversized body collapses to
///    a `'<truncated N bytes>'` marker capped at
///    [ObservabilityConfig.maxBodyBytes]).
///  * `path` — [DiagRedaction.scrubPath]; the query string is always
///    dropped (it commonly carries tokens/reset codes).
///  * `errorMessage` — [SecretRedactor.redactString].
///
/// Byte sizes are computed from the RAW, pre-redaction payload (a
/// `Content-Length` response header when present, else the encoded size of
/// the body Dio actually holds) so they reflect true payload weight even
/// when a body is truncated or body capture is switched off. [ObsApiEvent]
/// has no dedicated size field, so — rather than touching the frozen event
/// model — the counts are folded into the already-redacted header maps
/// under the synthetic (non-wire) keys [_requestBytesKey]/
/// [_responseBytesKey], clearly namespaced so they can never be mistaken
/// for a real HTTP header.
///
/// Zero-cost when disabled: [onRequest] does only the cheap stopwatch/seq
/// bookkeeping described above; the full event is never built unless
/// `Observability.instance.recording` AND the `api` signal are both on (see
/// [_emit]). In a production build this class is never even instantiated —
/// see wiring point W2, gated on `kObsCompiledIn`.
final class ObsDioInterceptor extends Interceptor {
  const ObsDioInterceptor();

  static const String _startedAtKey = 'jeeb.obs.startedAtMicros';
  static const String _seqKey = 'jeeb.obs.seq';
  static const String _screenKey = 'jeeb.obs.screen';

  /// Correlation-id header names, checked case-insensitively — mirrors
  /// `DiagDioInterceptor._correlationId`.
  static const List<String> _correlationHeaderNames = [
    'x-correlation-id',
    'x-request-id',
  ];

  /// Free-form error messages are capped to this many characters before
  /// redaction/storage — no magic literal at the call site.
  static const int _maxErrorMessageChars = 240;

  /// Synthetic (non-wire) keys folded into the redacted header maps to
  /// carry payload byte sizes — see the class doc.
  static const String _requestBytesKey = 'x-obs-request-bytes';
  static const String _responseBytesKey = 'x-obs-response-bytes';

  /// Mirrors `Observability._unknownSessionId` (private to that class) —
  /// the fallback stamped on an event built before `install()` has minted a
  /// real session id.
  static const String _unknownSessionId = 'unknown-session';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;
    if (Observability.instance.recording) {
      options.extra[_seqKey] = Observability.instance.nextSeq();
      final screen = Observability.instance.currentScreen;
      if (screen != null) options.extra[_screenKey] = screen;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _emit(response.requestOptions, response: response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _emit(err.requestOptions, response: err.response, error: err);
    handler.next(err);
  }

  /// Builds and records one [ObsApiEvent] iff the tool is actively recording
  /// the `api` signal. Fail-soft is inherited from `Observability.record` —
  /// this never throws into the Dio chain.
  static void _emit(
    RequestOptions options, {
    Response<dynamic>? response,
    DioException? error,
  }) {
    if (!Observability.instance.recording ||
        !ObservabilityConfig.instance.signalEnabled(ObsEventType.api)) {
      return;
    }
    Observability.instance.record(
      _buildEvent(options, response: response, error: error),
    );
  }

  static ObsApiEvent _buildEvent(
    RequestOptions options, {
    Response<dynamic>? response,
    DioException? error,
  }) {
    final seq = _seqFor(options);
    return ObsApiEvent(
      id: Observability.instance.newEventId(ObsEventType.api, seq),
      sessionId: Observability.instance.sessionId ?? _unknownSessionId,
      // NOTE: `Observability.clock` is `@visibleForTesting` (only usable
      // from observability.dart itself or a test) — unlike the recordX
      // convenience wrappers, this interceptor builds the full event
      // itself, so it reads the wall clock directly, exactly as
      // `DiagDioInterceptor` already does for its own timing.
      timestampUtc: DateTime.now().toUtc(),
      seq: seq,
      method: options.method.toUpperCase(),
      path: DiagRedaction.scrubPath(options.path),
      statusCode: response?.statusCode,
      durationMs: _elapsedMs(options),
      requestHeaders: _requestHeaders(options),
      requestBody: _requestBody(options),
      responseHeaders: _responseHeaders(response),
      responseBody: _responseBody(response),
      correlationId: _correlationId(options, response),
      screen: _screenFor(options),
      errorType: error?.type.name,
      errorMessage: _errorMessage(error),
    );
  }

  // ── field builders (each redacts before returning) ──────────────────────

  static Map<String, Object?> _requestHeaders(RequestOptions options) {
    final redacted = SecretRedactor.redactHeaders(
      _toObjectMap(options.headers),
    );
    final bytes = _encodedLength(options.data);
    if (bytes == null) return redacted;
    return <String, Object?>{...redacted, _requestBytesKey: bytes};
  }

  static Object? _requestBody(RequestOptions options) {
    final config = ObservabilityConfig.instance;
    if (!config.captureApiBodies) return null;
    return SecretRedactor.redactAndTruncate(
      _jsonSafeBody(options.data),
      full: config.redactionEnabled,
      maxBytes: config.maxBodyBytes,
    );
  }

  static Map<String, Object?> _responseHeaders(Response<dynamic>? response) {
    if (response == null) return const <String, Object?>{};
    final redacted = SecretRedactor.redactHeaders(
      _flattenHeaders(response.headers),
    );
    final bytes = _responseByteLength(response);
    if (bytes == null) return redacted;
    return <String, Object?>{...redacted, _responseBytesKey: bytes};
  }

  static Object? _responseBody(Response<dynamic>? response) {
    final config = ObservabilityConfig.instance;
    if (response == null || !config.captureApiBodies) return null;
    return SecretRedactor.redactAndTruncate(
      _jsonSafeBody(response.data),
      full: config.redactionEnabled,
      maxBytes: config.maxBodyBytes,
    );
  }

  static String? _errorMessage(DioException? error) {
    if (error == null) return null;
    final raw = error.message ?? error.error?.toString() ?? error.type.name;
    final capped = raw.length > _maxErrorMessageChars
        ? '${raw.substring(0, _maxErrorMessageChars)}…'
        : raw;
    return SecretRedactor.redactString(capped);
  }

  // ── timing / correlation / screen (mirrors DiagDioInterceptor) ─────────

  static int _seqFor(RequestOptions options) {
    final stashed = options.extra[_seqKey];
    if (stashed is int) return stashed;
    return Observability.instance.nextSeq();
  }

  static String? _screenFor(RequestOptions options) {
    final screen = options.extra[_screenKey];
    return screen is String ? screen : null;
  }

  static int _elapsedMs(RequestOptions options) {
    final started = options.extra[_startedAtKey];
    if (started is! int) return 0;
    final micros = DateTime.now().microsecondsSinceEpoch - started;
    return micros < 0 ? 0 : micros ~/ 1000;
  }

  /// Opaque correlation id (NOT a secret) — checked on the request first
  /// (the common client-generated-id pattern `DiagDioInterceptor` mirrors),
  /// falling back to the response in case only the server echoes one.
  static String? _correlationId(
    RequestOptions options,
    Response<dynamic>? response,
  ) {
    for (final name in _correlationHeaderNames) {
      final fromRequest = _headerIgnoreCase(options.headers, name);
      if (fromRequest != null && fromRequest.isNotEmpty) return fromRequest;
    }
    if (response == null) return null;
    for (final name in _correlationHeaderNames) {
      final values = response.headers[name];
      if (values != null && values.isNotEmpty) return values.first;
    }
    return null;
  }

  static String? _headerIgnoreCase(Map<String, dynamic> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value?.toString();
    }
    return null;
  }

  // ── header/body shape helpers (JSON-safe, never throw) ──────────────────

  static Map<String, Object?> _toObjectMap(Map<String, dynamic> headers) =>
      headers.map((key, value) => MapEntry(key, value as Object?));

  static Map<String, Object?> _flattenHeaders(Headers headers) {
    final out = <String, Object?>{};
    headers.map.forEach((key, values) {
      out[key] = values.length == 1 ? values.first : values;
    });
    return out;
  }

  /// Reduces an arbitrary Dio request/response `data` value to something
  /// [SecretRedactor]/`jsonEncode` can safely walk: JSON scalars/collections
  /// pass through, [FormData] becomes a field/file summary, raw byte buffers
  /// become a length-only marker (dumping a binary upload/download element
  /// by element would be both useless and enormous), anything else degrades
  /// to a type-name placeholder. Never throws.
  static Object? _jsonSafeBody(Object? raw) {
    if (raw == null) return null;
    try {
      if (raw is FormData) return _formDataSummary(raw);
      if (raw is List<int>) return <String, Object?>{'_bytes': raw.length};
      if (raw is Map ||
          raw is List ||
          raw is String ||
          raw is num ||
          raw is bool) {
        return raw;
      }
      return '<non-serializable body: ${raw.runtimeType}>';
    } catch (_) {
      return '<non-serializable body>';
    }
  }

  static Map<String, Object?> _formDataSummary(FormData form) {
    final fields = <String, Object?>{
      for (final entry in form.fields) entry.key: entry.value,
    };
    final files = <Map<String, Object?>>[
      for (final entry in form.files)
        <String, Object?>{'field': entry.key, 'filename': entry.value.filename},
    ];
    return <String, Object?>{
      if (fields.isNotEmpty) 'fields': fields,
      if (files.isNotEmpty) 'files': files,
    };
  }

  /// Best-effort byte length of a raw (pre-redaction) request/response
  /// payload. Never throws — an unencodable value degrades to `null` rather
  /// than surfacing into the interceptor's hot path.
  static int? _encodedLength(Object? data) {
    if (data == null) return null;
    try {
      if (data is FormData) return data.length;
      if (data is String) return utf8.encode(data).length;
      if (data is List<int>) return data.length;
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return null;
    }
  }

  /// Prefers the wire `Content-Length` (also correct for a compressed body,
  /// where the decoded-size fallback below would be misleading); falls back
  /// to measuring the decoded `response.data` Dio already holds.
  static int? _responseByteLength(Response<dynamic> response) {
    try {
      final raw = response.headers.value(Headers.contentLengthHeader);
      final headerBytes = raw == null ? null : int.tryParse(raw);
      if (headerBytes != null) return headerBytes;
    } catch (_) {
      // A multi-valued content-length never happens in practice; fall
      // through to the decoded-body measurement below instead.
    }
    return _encodedLength(response.data);
  }
}
