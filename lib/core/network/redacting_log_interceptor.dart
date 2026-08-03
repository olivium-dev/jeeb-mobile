import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diag_redaction.dart';

class RedactingLogInterceptor extends Interceptor {
  const RedactingLogInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final headers = DiagRedaction.redactHeaders(options.headers);
      debugPrint(
        '[http→] ${options.method} ${DiagRedaction.scrubPath(options.uri.toString())}'
        ' headers=$headers body=${_redactBody(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[http←] ${response.statusCode} ${response.requestOptions.method} '
        '${DiagRedaction.scrubPath(response.requestOptions.path)} '
        'body=${_redactBody(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[http✗] ${err.response?.statusCode} ${err.requestOptions.method} '
        '${DiagRedaction.scrubPath(err.requestOptions.path)} '
        'body=${_redactBody(err.response?.data)}',
      );
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
