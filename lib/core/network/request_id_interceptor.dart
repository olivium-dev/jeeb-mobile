import 'package:dio/dio.dart';

import '../idempotency/operation_id.dart';

/// NET-27: one client-side correlation id per request, so a report ("it failed
/// at 10:04") can be matched to a gateway trace. Placed before the diagnostics
/// interceptor, which reads the header it writes.
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({OperationIdFactory? idFactory})
      : _newId = idFactory ?? newOperationId;

  final OperationIdFactory _newId;

  static const String headerName = 'X-Request-Id';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final present = options.headers.keys.any(
      (key) => key.toLowerCase() == headerName.toLowerCase(),
    );
    if (!present) options.headers[headerName] = _newId();
    handler.next(options);
  }
}
