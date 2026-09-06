// Shared scripted transport for the WP-6 OTP-handover repository tests.

import 'package:dio/dio.dart';

/// Answers every request from a script — no `http_mock_adapter`, no socket.
class ScriptedAdapter extends Interceptor {
  ScriptedAdapter(this._respond);

  final void Function(RequestOptions options, ResponseHandler responder)
      _respond;

  RequestOptions? lastRequest;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    _respond(options, ResponseHandler(options, handler));
  }
}

class ResponseHandler {
  ResponseHandler(this._options, this._handler);

  final RequestOptions _options;
  final RequestInterceptorHandler _handler;

  void respondWith(int status, {Object? body}) {
    _handler.resolve(
      Response<Object?>(
        requestOptions: _options,
        statusCode: status,
        data: body,
      ),
    );
  }

  void failWithStatus(int status, {Object? body}) {
    _handler.reject(
      DioException(
        requestOptions: _options,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: _options,
          statusCode: status,
          data: body,
        ),
      ),
    );
  }

  void failWithType(DioExceptionType type) {
    _handler.reject(DioException(requestOptions: _options, type: type));
  }
}

Dio scriptedDio(
  void Function(RequestOptions options, ResponseHandler responder) respond,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'));
  dio.interceptors.add(ScriptedAdapter(respond));
  return dio;
}

/// An RFC 7807 body with a DOMAIN type suffix.
Map<String, Object?> problem(
  String suffix, {
  Map<String, Object?> extensions = const <String, Object?>{},
}) => <String, Object?>{
  'type': 'https://jeeb.app/errors/$suffix',
  'title': 'server prose that must never be rendered',
  'detail': 'more server prose',
  ...extensions,
};
