import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/auth_interceptor.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/app_failure_copy.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _ScenarioAdapter implements HttpClientAdapter {
  _ScenarioAdapter(this.response);

  final Map<String, dynamic> response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    response['body'] as String,
    response['status'] as int,
    headers: <String, List<String>>{
      for (final entry in (response['headers'] as Map<String, dynamic>).entries)
        entry.key.toLowerCase(): <String>[entry.value as String],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  final files =
      Directory('tool/fault_proxy/scenarios')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  test('P08 catalogue is S00-S16 with no dropped S17', () {
    expect(files.length, 17);
    expect(
      files.map(
        (file) => (jsonDecode(file.readAsStringSync()) as Map)['scenario'],
      ),
      List.generate(17, (index) => 'S${index.toString().padLeft(2, '0')}'),
    );
  });

  for (final file in files) {
    final document =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final expected = document['expect'] as Map<String, dynamic>;
    final rules = document['rules'] as List<dynamic>;
    if (rules.isEmpty) continue;
    final responses = <Map<String, dynamic>>[
      (rules.first as Map<String, dynamic>)['respond'] as Map<String, dynamic>,
      for (final variant in document['variants'] as List<dynamic>? ?? [])
        (variant as Map<String, dynamic>)['respond'] as Map<String, dynamic>,
    ];

    for (final locale in ['en', 'ar']) {
      final rawArb = File('lib/l10n/app_$locale.arb').readAsStringSync();
      final arb = jsonDecode(rawArb) as Map<String, dynamic>;
      final l10n = debugLoadAppLocalizationsSync(Locale(locale), rawArb);
      for (var index = 0; index < responses.length; index++) {
        test(
          '${document['scenario']} variant $index transforms/maps/copies $locale',
          () async {
            final dio = Dio(
              BaseOptions(baseUrl: 'https://offline-fixture.invalid'),
            )..httpClientAdapter = _ScenarioAdapter(responses[index]);
            addTearDown(() => dio.close(force: true));
            Object? caught;
            try {
              await dio.get<Map<String, dynamic>>(
                '/v1/users/me',
                options: Options(
                  extra: <String, dynamic>{
                    // S07's auth-chain behavior is a separate device/integration gate.
                    if (expected['recovering'] == true)
                      TokenRefreshInterceptor.recoveringFlag: true,
                  },
                ),
              );
            } catch (error) {
              caught = error;
            }
            expect(
              caught,
              isNotNull,
              reason: 'malformed success must not become a profile',
            );
            final failure = AppFailure.of(caught!);
            expect(failure.kind.name, expected['kind']);
            if (expected.containsKey('unavailable')) {
              expect(
                (failure as ServerFailure).unavailable,
                expected['unavailable'],
              );
            }
            if (expected.containsKey('retryAfterSeconds')) {
              final after = switch (failure) {
                ServerFailure(:final retryAfter) => retryAfter,
                RateLimitedFailure(:final retryAfter) => retryAfter,
                _ => null,
              };
              expect(after?.inSeconds, expected['retryAfterSeconds']);
            }
            if (expected['recovering'] == true) {
              expect((failure as UnauthorizedFailure).recovering, isTrue);
              expect(failure.isRetryable, isTrue);
            }
            if (expected['problemAbsent'] == true) {
              expect(failure.problem, isNull);
            }
            if (expected['parse'] == true) {
              expect((failure as UnknownFailure).parse, isTrue);
            }
            if (expected.containsKey('reasonCode')) {
              expect(
                (failure as ForbiddenFailure).reasonCode,
                expected['reasonCode'],
              );
            }
            if (expected.containsKey('typeSuffix')) {
              expect(failure.problem?.typeSuffix, expected['typeSuffix']);
            }
            if (expected.containsKey('fieldError')) {
              expect(
                (failure as ValidationFailure).fieldErrors,
                contains(expected['fieldError']),
              );
            }
            final copy = failureCopy(l10n, failure);
            expect(copy.title, arb[expected['copyTitle']]);
            expect(
              copy.body,
              expected['copyBody'] == 'errorRateLimitedRetryIn'
                  ? l10n.errorRateLimitedRetryIn(
                      expected['retryAfterSeconds'] as int,
                    )
                  : arb[expected['copyBody']],
            );
            expect(copy.retryable, expected['retryable']);
            expect(copy.body, isNot(contains('traceId')));
            expect(copy.body, isNot(contains('http')));
          },
        );
      }
    }
  }
}
