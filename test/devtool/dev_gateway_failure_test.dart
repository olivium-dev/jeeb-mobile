import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/app_failure_copy.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_failure.dart';

import '../support/midnight_test_harness.dart';
import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';

DevGatewayException _fromDio({
  int? status,
  Map<String, dynamic>? problem,
  DioExceptionType type = DioExceptionType.badResponse,
  bool money = false,
}) {
  final request = RequestOptions(path: '/dev/test');
  return DevGatewayException.fromDio(
    DioException(
      requestOptions: request,
      type: type,
      response: status == null
          ? null
          : Response(
              requestOptions: request,
              statusCode: status,
              data: problem,
            ),
    ),
    action: 'load users',
    uncertainOnMoneyTransport: money,
  );
}

void main() {
  for (final type in DioExceptionType.values) {
    test('transport $type has readable guidance without enum names', () {
      final error = _fromDio(type: type);
      expect(error.message, isNot(contains('(${type.name})')));
      expect(error.message, contains('Could not load users:'));
      expect(error.message, isNot(contains('Try again')));
      expect(error.cause?.type, type);
      if (type != DioExceptionType.cancel) {
        expect(error.message, contains('Check'));
      }
    });
  }
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('title-only 503 uses localized body in $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final error = _fromDio(
          status: 503,
          problem: {'title': 'Service Unavailable', 'detail': '  '},
        );
        useReduceMotion(tester);
        await tester.pumpWidget(
          wrapMidnight(
            JeebFailureBlock(
              failure: devGatewayFailure(error),
              identifier: 'devtool_gateway_error',
              bodyOverride: devGatewayMessage(error),
              onRetry: () {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final copy = failureCopy(
          l10nOf(tester, JeebFailureBlock),
          devGatewayFailure(error),
        );
        expect(find.text(copy.body), findsOneWidget);
        expect(find.text('Service Unavailable'), findsNothing);
        expect(
          find.bySemanticsIdentifier('devtool_gateway_error'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });
  }
  test(
    'generic server title remains diagnostic without overriding kit copy',
    () {
      final error = _fromDio(
        status: 503,
        problem: {'title': 'Service Unavailable'},
      );
      expect(error.message, 'Service Unavailable');
      expect(devGatewayMessage(error), isNull);
      expect(devGatewayMessage(_fromDio(status: 503)), isNull);
    },
  );
  test('meaningful server detail and explicit constructor hints survive', () {
    final error = _fromDio(
      status: 503,
      problem: {
        'title': 'Service Unavailable',
        'detail': 'The sandbox is restarting. Wait until it is ready.',
      },
    );
    expect(
      devGatewayMessage(error),
      'The sandbox is restarting. Wait until it is ready.',
    );
    expect(
      devGatewayMessage(const DevGatewayException('Custom hint')),
      'Custom hint',
    );
  });
  test('OTP title hints and auth semantics survive', () {
    final otp = _fromDio(
      status: 400,
      problem: {
        'type': 'https://jeeb.dev/errors/otp-expired',
        'title': 'Request a new OTP.',
      },
    );
    expect(devGatewayMessage(otp), 'Request a new OTP.');
    for (final status in [401, 403, 404, 410]) {
      final error = _fromDio(
        status: status,
        problem: {'title': 'Generic title'},
      );
      expect(devGatewayMessage(error), contains('Could not load users:'));
      expect(devGatewayFailure(error).isRetryable, isFalse);
    }
  });
  test(
    'uncertain money retains reconcile instruction for transport and 503',
    () {
      for (final status in <int?>[null, 503]) {
        final error = _fromDio(status: status, money: true);
        expect(error.isUncertainWalletMove, isTrue);
        expect(
          devGatewayMessage(error),
          contains('Do not retry this operation'),
        );
        expect(devGatewayMessage(error), contains('reconcile'));
      }
      for (final suffix in [
        'partner-wallet-uncertain',
        'partner-wallet-in-flight',
      ]) {
        final error = _fromDio(
          status: 503,
          problem: {
            'type': 'https://jeeb.dev/errors/$suffix',
            'detail': 'Try again',
          },
        );
        expect(error.isUncertainWalletMove, isTrue);
        expect(
          devGatewayMessage(error),
          contains('Do not retry this operation'),
        );
      }
    },
  );
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
