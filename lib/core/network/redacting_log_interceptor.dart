import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diag_redaction.dart';

class RedactingLogInterceptor extends Interceptor {
  const RedactingLogInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final path = DiagRedaction.scrubPath(options.path);
      if (DiagRedaction.isBodySuppressedPath(options.path)) {
        debugPrint('[http→] ${options.method} $path');
      } else {
        final headers = DiagRedaction.redactHeaders(options.headers);
        debugPrint(
          '[http→] ${options.method} $path'
          ' headers=$headers body=${_redactBody(options.data)}',
        );
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      final options = response.requestOptions;
      final path = DiagRedaction.scrubPath(options.path);
      if (DiagRedaction.isBodySuppressedPath(options.path)) {
        debugPrint('[http←] ${response.statusCode} ${options.method} $path');
      } else {
        debugPrint(
          '[http←] ${response.statusCode} ${options.method} '
          '$path body=${_redactBody(response.data)}',
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final options = err.requestOptions;
      final path = DiagRedaction.scrubPath(options.path);
      if (DiagRedaction.isBodySuppressedPath(options.path)) {
        debugPrint('[http✗] ${options.method} $path');
      } else {
        debugPrint(
          '[http✗] ${err.response?.statusCode} ${options.method} '
          '$path body=${_redactBody(err.response?.data)}',
        );
      }
    }
    handler.next(err);
  }

  static Object? _redactBody(Object? data) {
    if (data is List<int>) return '<binary ${data.length} bytes>';
    if (data is Map<String, Object?>) return DiagRedaction.scrubMap(data);
    if (data is Map) {
      return DiagRedaction.scrubMap(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return data;
  }
}
