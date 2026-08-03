import 'package:dio/dio.dart';

import 'diag.dart';

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
