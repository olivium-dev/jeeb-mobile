import 'package:dio/dio.dart';

import 'diag.dart';
import 'diag_redaction.dart';

/// Dio [Interceptor] that emits one `[jeeb-diag] {"t":"api",...}` line per HTTP
/// round-trip: method, path, status, duration, correlation id, a monotonic
/// per-session sequence number, and the screen route active at CALL time — and
/// NOTHING else.
///
/// Redaction by design: this interceptor NEVER reads or logs the Authorization
/// header, the request/response body, or the query string. Only the path
/// (query-stripped via [DiagRedaction.scrubPath]), the status code, the elapsed
/// milliseconds, and an `x-correlation-id`/`x-request-id` header (an opaque id,
/// not a secret) reach the line. It is the low-fidelity, safe-by-construction
/// counterpart to Dio's `LogInterceptor` (which dumps headers+bodies and must
/// stay debug-gated and redacted separately).
///
/// Timing uses a monotonic stopwatch stashed in `RequestOptions.extra`, so the
/// `ms` figure is the true wall-clock of the request as Dio saw it (including
/// a token-refresh retry, which re-enters `onRequest` and restarts the clock).
///
/// Context (diag-persistence lane): `seq` ([Diag.nextApiSeq]) and `screen`
/// ([Diag.currentScreen]) are both captured in `onRequest` — at the moment the
/// call FIRES — so concurrent requests keep distinct ordered ids and a call is
/// attributed to the screen that made it even when its response lands after
/// the user has navigated away.
class DiagDioInterceptor extends Interceptor {
  const DiagDioInterceptor();

  static const String _startedAtKey = 'jeeb.diag.startedAtMicros';
  static const String _seqKey = 'jeeb.diag.seq';
  static const String _screenKey = 'jeeb.diag.screen';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;
    if (Diag.enabled) {
      options.extra[_seqKey] = Diag.nextApiSeq();
      final screen = Diag.currentScreen;
      if (screen != null) options.extra[_screenKey] = screen;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _emit(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // A 4xx/5xx surfaces here (Dio treats non-2xx as an error) as does a
    // transport failure (status null → logged as null so a timeout is visible).
    _emit(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _emit(RequestOptions options, int? status) {
    if (!Diag.enabled) return;
    final seq = options.extra[_seqKey];
    final screen = options.extra[_screenKey];
    Diag.api(
      method: options.method,
      path: options.path,
      status: status,
      ms: _elapsedMs(options),
      reqId: _correlationId(options),
      seq: seq is int ? seq : null,
      screen: screen is String ? screen : null,
    );
  }

  static int _elapsedMs(RequestOptions options) {
    final started = options.extra[_startedAtKey];
    if (started is! int) return 0;
    final micros = DateTime.now().microsecondsSinceEpoch - started;
    return micros < 0 ? 0 : micros ~/ 1000;
  }

  /// Reads an opaque correlation id if the request carries one. This is an
  /// echo/trace id, NOT a credential — safe to log for cross-referencing a
  /// client line against a gateway log line.
  static String? _correlationId(RequestOptions options) {
    for (final key in const ['x-correlation-id', 'x-request-id']) {
      final value = _headerIgnoreCase(options.headers, key);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _headerIgnoreCase(Map<String, dynamic> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value?.toString();
    }
    return null;
  }
}
