import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/request_summary/data/dio_recipient_phone_resolver.dart';

/// Resolves GET /v1/users/me to [body]/[status] without hitting the network.
Dio _dioRespond(Object? body, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(data: body, statusCode: status, requestOptions: options),
      ),
    ),
  );
  return dio;
}

Dio _dioError(DioExceptionType type, {int? status}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          type: type,
          response: status != null
              ? Response(data: null, statusCode: status, requestOptions: options)
              : null,
        ),
      ),
    ),
  );
  return dio;
}

void main() {
  group('DioRecipientPhoneResolver — GET /v1/users/me phone default', () {
    test('reads the `phone` field from getMe', () async {
      String? capturedPath;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPath = options.path;
            handler.resolve(
              Response(
                data: {'id': 'u1', 'phone': '+96170123456', 'name': 'Nour'},
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );

      final phone = await DioRecipientPhoneResolver(dio).resolve();

      expect(capturedPath, '/v1/users/me');
      expect(phone, '+96170123456');
    });

    test('accepts the phoneE164 alias', () async {
      final phone = await DioRecipientPhoneResolver(
        _dioRespond({'id': 'u1', 'phoneE164': '+96171999888'}),
      ).resolve();
      expect(phone, '+96171999888');
    });

    test('returns null when getMe carries no phone', () async {
      final phone = await DioRecipientPhoneResolver(
        _dioRespond({'id': 'u1', 'name': 'Nour'}),
      ).resolve();
      expect(phone, isNull);
    });

    test('returns null on an empty/whitespace phone', () async {
      final phone = await DioRecipientPhoneResolver(
        _dioRespond({'id': 'u1', 'phone': '   '}),
      ).resolve();
      expect(phone, isNull);
    });

    test('degrades to null on a network error (never throws)', () async {
      final phone = await DioRecipientPhoneResolver(
        _dioError(DioExceptionType.connectionError),
      ).resolve();
      expect(phone, isNull);
    });

    test('degrades to null on a 401', () async {
      final phone = await DioRecipientPhoneResolver(
        _dioError(DioExceptionType.badResponse, status: 401),
      ).resolve();
      expect(phone, isNull);
    });
  });
}
