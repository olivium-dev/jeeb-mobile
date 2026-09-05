import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/data/dio_dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';

const _submission = DmOnboardingSubmission(
  state: 'Mount Lebanon',
  country: 'Lebanon',
  street: 'Main St',
  address: 'Bldg 4',
  homeBaseLat: 33.8938,
  homeBaseLng: 35.5018,
  homeBaseLabel: 'Beirut',
  portraitObjectRef: 'cdn/objects/portrait-1',
);

/// Records every request and answers with [status] (+ optional [body]).
({Dio dio, List<RequestOptions> requests}) _scripted({
  required int status,
  Map<String, dynamic>? body,
}) {
  final requests = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: body,
        );
        if (status >= 200 && status < 300) {
          handler.resolve(response);
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      },
    ),
  );
  return (dio: dio, requests: requests);
}

void main() {
  // UX-05: the gateway used to discard its Dio and resolve unconditionally, so
  // the wizard always "succeeded" and nothing ever reached the backend.
  test('POSTs the full DTO, including portrait_object_ref', () async {
    final scripted = _scripted(status: 200, body: <String, dynamic>{});

    await DioDmOnboardingGateway(scripted.dio, operationId: 'op-1')
        .submit(_submission);

    expect(scripted.requests, hasLength(1));
    final RequestOptions request = scripted.requests.single;
    expect(request.method, 'POST');
    expect(request.path, DmOnboardingGateway.submitPath);
    expect(request.headers['Idempotency-Key'], 'op-1');
    final body = request.data! as Map<String, dynamic>;
    expect(body['state'], 'Mount Lebanon');
    expect(body['country'], 'Lebanon');
    expect(body['street'], 'Main St');
    expect(body['address'], 'Bldg 4');
    expect(body['home_base_lat'], 33.8938);
    expect(body['home_base_lng'], 35.5018);
    expect(body['home_base_label'], 'Beirut');
    expect(body['portrait_object_ref'], 'cdn/objects/portrait-1');
  });

  // The route is not deployed yet (stage1/OWNER-CONFIRM.md). A missing
  // endpoint must never block the jeeber funnel.
  for (final int status in <int>[404, 405, 501]) {
    test('$status (route not deployed) resolves normally', () async {
      final scripted = _scripted(status: status);

      await expectLater(
        DioDmOnboardingGateway(scripted.dio).submit(_submission),
        completes,
      );
      expect(scripted.requests, hasLength(1));
    });
  }

  // Item 32: production builds the gateway with no ctor id — the cubit's scope
  // rides on the submission itself.
  test('the submission carries Idempotency-Key with no ctor operationId',
      () async {
    final scripted = _scripted(status: 200, body: <String, dynamic>{});
    const submission = DmOnboardingSubmission(
      state: 'Mount Lebanon',
      country: 'Lebanon',
      street: 'Main St',
      address: 'Bldg 4',
      homeBaseLat: 33.8938,
      homeBaseLng: 35.5018,
      operationId: 'op-from-cubit',
    );

    await DioDmOnboardingGateway(scripted.dio).submit(submission);
    await DioDmOnboardingGateway(scripted.dio).submit(submission);

    expect(scripted.requests, hasLength(2));
    for (final RequestOptions request in scripted.requests) {
      expect(request.headers['Idempotency-Key'], 'op-from-cubit');
    }
    expect(
      (scripted.requests.first.data! as Map<String, dynamic>)
          .containsKey('operationId'),
      isFalse,
      reason: 'the scope is a header, never a body field',
    );
  });

  test('a bare POST with no scope anywhere sends no Idempotency-Key',
      () async {
    final scripted = _scripted(status: 200, body: <String, dynamic>{});

    await DioDmOnboardingGateway(scripted.dio).submit(_submission);

    expect(
      scripted.requests.single.headers.containsKey('Idempotency-Key'),
      isFalse,
    );
  });

  // D1: this endpoint's problem type has no `/errors/` segment, so
  // `typeSuffix` alone reads null and the 409 degraded to submitFailed.
  test('409 out_of_coverage is typed even without an /errors/ type segment',
      () async {
    final scripted = _scripted(
      status: 409,
      body: <String, dynamic>{
        'type': 'https://problems.jeeb.lb/form-builder/out_of_coverage',
        'title': 'Outside the service area',
      },
    );

    await expectLater(
      DioDmOnboardingGateway(scripted.dio).submit(_submission),
      throwsA(isA<DmOnboardingOutOfCoverageException>()),
    );
  });

  test('409 out_of_coverage is its own typed decision', () async {
    final scripted = _scripted(
      status: 409,
      body: <String, dynamic>{
        'type': 'https://problems.jeeb.lb/errors/out_of_coverage',
        'title': 'Outside the service area',
      },
    );

    await expectLater(
      DioDmOnboardingGateway(scripted.dio).submit(_submission),
      throwsA(isA<DmOnboardingOutOfCoverageException>()),
    );
  });

  test('500 is a classified gateway failure, never a silent success', () async {
    final scripted = _scripted(status: 500);

    await expectLater(
      DioDmOnboardingGateway(scripted.dio).submit(_submission),
      throwsA(
        isA<DmOnboardingGatewayException>().having(
          (e) => e.failure.kind,
          'kind',
          AppFailureKind.server,
        ),
      ),
    );
  });

  test('a 409 that is NOT out_of_coverage stays a gateway failure', () async {
    final scripted = _scripted(
      status: 409,
      body: <String, dynamic>{
        'type': 'https://problems.jeeb.lb/errors/already_onboarded',
      },
    );

    await expectLater(
      DioDmOnboardingGateway(scripted.dio).submit(_submission),
      throwsA(isA<DmOnboardingGatewayException>()),
    );
  });
}
