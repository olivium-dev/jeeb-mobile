import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_failure.dart';

void main() {
  for (final entry in <int, Type>{
    401: UnauthorizedFailure,
    403: ForbiddenFailure,
    404: NotFoundFailure,
    410: GoneFailure,
    429: RateLimitedFailure,
    503: ServerFailure,
  }.entries) {
    test('maps Dev Gateway ${entry.key}', () {
      final failure = devGatewayFailure(
        DevGatewayException('hint', statusCode: entry.key),
      );
      expect(failure.runtimeType, entry.value);
      if (failure is ServerFailure) {
        expect(failure.status, 503);
        expect(failure.isRetryable, isTrue);
      }
    });
  }
  test('null status and arbitrary exceptions are unknown', () {
    expect(
      devGatewayFailure(const DevGatewayException('hint')),
      isA<UnknownFailure>(),
    );
    expect(devGatewayFailure(StateError('private')), isA<UnknownFailure>());
  });
  test('Dio timeouts and classified failures retain their kind', () {
    expect(
      devGatewayFailure(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      isA<TimeoutFailure>(),
    );
    const failure = ForbiddenFailure();
    expect(devGatewayFailure(failure), same(failure));
  });
  test('only gateway-authored messages reach the UI', () {
    expect(devGatewayMessage(const DevGatewayException('hint')), 'hint');
    expect(devGatewayMessage(StateError('private')), isNull);
  });
}
