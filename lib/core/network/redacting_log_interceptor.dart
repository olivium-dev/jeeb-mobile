import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/diag_redaction.dart';

/// Debug-only Dio logger that keeps the ergonomics of Dio's `LogInterceptor`
/// (method, path, status, headers, body) but REDACTS every secret before it
/// reaches logcat.
///
/// Why it exists: the stock `LogInterceptor(requestHeader/requestBody/
/// responseBody: true)` printed the full `Authorization: Bearer` JWT header,
/// the FCM registration token in the `PUT /api/PushNotification/register` body,
/// and the `accessToken`/`refreshToken` in `/v1/auth/login` + `/v1/auth/refresh`
/// response bodies — all in cleartext. This interceptor closes that dev-logging
/// token-leak: sensitive headers ([DiagRedaction.isSensitiveHeader]) and
/// sensitive body keys ([DiagRedaction.isSensitiveKey]) are replaced with a
/// non-reversible correlation handle (`tok:<fnv8>~<last4>`), so a QA run can
/// still correlate "same token" across lines without the token ever printing.
///
/// It is added ONLY under `kDebugMode` (see `DioClient`), so in release/profile
/// the whole thing is tree-shaken out and nothing is logged at all.
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

  /// Redacts a JSON-ish body. Maps are scrubbed key-by-key
  /// ([DiagRedaction.scrubMap]); anything else is passed through unchanged
  /// (scalars/lists carry no keyed secret — a bare token value is never sent as
  /// a top-level primitive body in this app).
  static Object? _redactBody(Object? data) {
    if (data is Map<String, Object?>) return DiagRedaction.scrubMap(data);
    if (data is Map) {
      return DiagRedaction.scrubMap(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return data;
  }
}
