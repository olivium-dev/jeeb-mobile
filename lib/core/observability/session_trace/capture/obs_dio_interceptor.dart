import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../diagnostics/diag_redaction.dart';
import '../model/obs_event.dart';
import '../observability.dart';
import '../observability_config.dart';
import '../secret_redactor.dart';

final class ObsDioInterceptor extends Interceptor {
  const ObsDioInterceptor();

  static final RegExp _authRecoveryPath = RegExp(
    r'^/(?:v1/)?auth/recovery/(?:request|verify)$',
    caseSensitive: false,
  );

  static final RegExp _authRefreshPath = RegExp(
    r'^/(?:v1/)?auth/refresh$',
    caseSensitive: false,
  );

  static final RegExp _deliveryCredentialPath = RegExp(
    r'^/(?:v1/)?(?:delivery|deliveries)/[^/]+/(?:otp(?:/verify)?|handover(?:-code)?(?:/verify)?)$',
    caseSensitive: false,
  );

  static const String _startedAtKey = 'jeeb.obs.startedAtMicros';
  static const String _captureKey = 'jeeb.obs.capture';

  static const List<String> _correlationHeaderNames = [
    'x-correlation-id',
    'x-request-id',
  ];

  static const int _maxErrorMessageChars = 240;

  static const String _requestBytesKey = 'x-obs-request-bytes';
  static const String _responseBytesKey = 'x-obs-response-bytes';

  static const List<String> _localServicePrefixes = <String>[
    '/auth-service',
    '/delivery-service',
  ];

  static void attachTo(Dio dio) {
    if (!kObsCompiledIn ||
        dio.interceptors.whereType<ObsDioInterceptor>().isNotEmpty) {
      return;
    }
    dio.interceptors.add(const ObsDioInterceptor());
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] ??= DateTime.now().microsecondsSinceEpoch;
    if (options.extra[_captureKey] is! ObsApiCapture) {
      final capture = Observability.instance.beginApiCapture();
      if (capture != null) {
        options.extra[_captureKey] = capture;
      }
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
    final capture = options.extra.remove(_captureKey);
    if (capture is! ObsApiCapture) {
      options.extra.remove(_startedAtKey);
      return;
    }
    try {
      final event = _buildEvent(
        options,
        capture: capture,
        response: response,
        error: error,
      );
      Observability.instance.completeApiCapture(capture, event);
    } catch (_) {
      Observability.instance.abandonApiCapture(capture);
    } finally {
      // A compatibility or auth replay reuses RequestOptions. Clearing the
      // first attempt's clock makes the replay a distinct wire timing.
      options.extra.remove(_startedAtKey);
    }
  }

  static ObsApiEvent _buildEvent(
    RequestOptions options, {
    required ObsApiCapture capture,
    Response<dynamic>? response,
    DioException? error,
  }) {
    final suppressPayload = _isMetadataOnlyPath(options.path);
    final correlationId = _correlationId(options, response);
    return ObsApiEvent(
      id: Observability.instance.newEventId(ObsEventType.api, capture.seq),
      sessionId: capture.sessionId,
      timestampUtc: DateTime.now().toUtc(),
      seq: capture.seq,
      method: options.method.toUpperCase(),
      path:
          SecretRedactor.redactNetworkPath(
            options.path,
            baseUrl: options.baseUrl,
          ) ??
          SecretRedactor.redacted,
      statusCode: response?.statusCode,
      durationMs: _elapsedMs(options),
      requestHeaders: suppressPayload
          ? const <String, Object?>{}
          : _requestHeaders(options),
      requestBody: suppressPayload ? null : _requestBody(options),
      responseHeaders: suppressPayload
          ? const <String, Object?>{}
          : _responseHeaders(response),
      responseBody: suppressPayload ? null : _responseBody(response),
      correlationId: suppressPayload ? null : correlationId,
      screen: capture.screen,
      errorType: error?.type.name,
      errorMessage: suppressPayload ? null : _errorMessage(error),
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
      maxBytes: config.maxBodyBytes,
    );
  }

  static String? _errorMessage(DioException? error) {
    if (error == null) return null;
    final raw = error.message ?? error.error?.toString() ?? error.type.name;
    final capped = raw.length > _maxErrorMessageChars
        ? '${raw.substring(0, _maxErrorMessageChars)}…'
        : raw;
    return SecretRedactor.redactLabel(capped);
  }

  static bool _isMetadataOnlyPath(String path) {
    if (DiagRedaction.isBodySuppressedPath(path)) return true;
    var scrubbed = DiagRedaction.scrubPath(path).toLowerCase();
    for (final prefix in _localServicePrefixes) {
      if (scrubbed == prefix || scrubbed.startsWith('$prefix/')) {
        scrubbed = scrubbed.substring(prefix.length);
        break;
      }
    }
    if (DiagRedaction.isBodySuppressedPath(scrubbed)) return true;
    final normalized = scrubbed.length > 1 && scrubbed.endsWith('/')
        ? scrubbed.substring(0, scrubbed.length - 1)
        : scrubbed;
    return _authRefreshPath.hasMatch(normalized) ||
        _authRecoveryPath.hasMatch(normalized) ||
        _deliveryCredentialPath.hasMatch(normalized);
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
      if (fromRequest != null && fromRequest.isNotEmpty) {
        return SecretRedactor.redactIdentifier(fromRequest);
      }
    }
    if (response == null) return null;
    for (final name in _correlationHeaderNames) {
      final values = response.headers[name];
      if (values != null && values.isNotEmpty) {
        return SecretRedactor.redactIdentifier(values.first);
      }
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
      return '<non-serializable body>';
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
    } catch (_) {}
    return _encodedLength(response.data);
  }
}
