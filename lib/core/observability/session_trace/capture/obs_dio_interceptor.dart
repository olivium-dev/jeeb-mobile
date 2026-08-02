import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../diagnostics/diag_redaction.dart';
import '../model/obs_event.dart';
import '../observability.dart';
import '../observability_config.dart';
import '../secret_redactor.dart';

final class ObsDioInterceptor extends Interceptor {
  const ObsDioInterceptor();

  static const String _startedAtKey = 'jeeb.obs.startedAtMicros';
  static const String _seqKey = 'jeeb.obs.seq';
  static const String _screenKey = 'jeeb.obs.screen';

  static const List<String> _correlationHeaderNames = [
    'x-correlation-id',
    'x-request-id',
  ];

  static const int _maxErrorMessageChars = 240;

  static const String _requestBytesKey = 'x-obs-request-bytes';
  static const String _responseBytesKey = 'x-obs-response-bytes';

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


  static Map<String, Object?> _toObjectMap(Map<String, dynamic> headers) =>
      headers.map((key, value) => MapEntry(key, value as Object?));

  static Map<String, Object?> _flattenHeaders(Headers headers) {
    final out = <String, Object?>{};
    headers.map.forEach((key, values) {
      out[key] = values.length == 1 ? values.first : values;
    });
    return out;
  }

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

  static int? _responseByteLength(Response<dynamic> response) {
    try {
      final raw = response.headers.value(Headers.contentLengthHeader);
      final headerBytes = raw == null ? null : int.tryParse(raw);
      if (headerBytes != null) return headerBytes;
    } catch (_) {
    }
    return _encodedLength(response.data);
  }
}
