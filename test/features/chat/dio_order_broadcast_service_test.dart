import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/dio_order_broadcast_service.dart';
import 'package:jeeb_mobile/features/chat/domain/order_broadcast_service.dart';

void main() {
  group('DioOrderBroadcastService matching/run contract', () {
    test('posts exactly once with only the persisted request id', () async {
      final harness = _MatchingHarness(_matchingResponse());

      await DioOrderBroadcastService(
        harness.dio,
      ).broadcast(requestId: 'req-42');

      expect(harness.requests, hasLength(1));
      expect(harness.requests.single.method, 'POST');
      expect(harness.requests.single.path, '/matching/run');
      expect(harness.requests.single.data, <String, Object?>{
        'requestId': 'req-42',
      });
    });

    test('parses the complete typed gateway response', () async {
      final harness = _MatchingHarness(_matchingResponse());

      final result = await DioOrderBroadcastService(
        harness.dio,
      ).broadcast(requestId: 'req-42');

      expect(result.requestId, 'req-42');
      expect(result.tierId, 'express');
      expect(result.radiusKm, 25.0);
      expect(result.notifiedCount, 4);
      expect(result.candidateCount, 9);
      expect(result.elapsedMs, 38);
      expect(result.candidates, hasLength(1));
      expect(result.candidates.single.userId, 'jeeber-1');
      expect(result.candidates.single.vehicleType, 'car');
      expect(result.candidates.single.distanceKm, 1.2);
      expect(result.candidates.single.rating, 4.8);
    });

    for (final blankId in ['', ' ', '\n\t']) {
      test(
        'rejects blank requestId ${blankId.codeUnits} without a call',
        () async {
          final harness = _MatchingHarness(_matchingResponse());

          await expectLater(
            DioOrderBroadcastService(harness.dio).broadcast(requestId: blankId),
            throwsA(_broadcastFailure(OrderBroadcastFailure.badRequest)),
          );
          expect(harness.requests, isEmpty);
        },
      );
    }

    final malformedCases = <String, void Function(Map<String, dynamic>)>{
      'mismatched requestId': (body) => body['requestId'] = 'req-other',
      'missing tierId': (body) => body.remove('tierId'),
      'negative radiusKm': (body) => body['radiusKm'] = -0.1,
      'negative notifiedCount': (body) => body['notifiedCount'] = -1,
      'negative candidateCount': (body) => body['candidateCount'] = -1,
      'non-list candidates': (body) => body['candidates'] = <String, dynamic>{},
      'negative candidate distance': (body) =>
          _candidate(body)['distanceKm'] = -0.1,
      'rating below gateway range': (body) => _candidate(body)['rating'] = -0.1,
      'rating above gateway range': (body) => _candidate(body)['rating'] = 5.1,
      'negative elapsedMs': (body) => body['elapsedMs'] = -1,
    };
    for (final entry in malformedCases.entries) {
      test('fails closed for ${entry.key}', () async {
        final body = _matchingResponse();
        entry.value(body);
        final harness = _MatchingHarness(body);

        await expectLater(
          DioOrderBroadcastService(harness.dio).broadcast(requestId: 'req-42'),
          throwsA(_broadcastFailure(OrderBroadcastFailure.unknown)),
        );
        expect(harness.requests, hasLength(1));
      });
    }

    test('source has no retired route or synthetic coordinate', () {
      final source = File(
        'lib/features/chat/data/dio_order_broadcast_service.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('/v1/matching/find-jeebers')));
      expect(source, isNot(contains('/v1/matching/broadcast')));
      expect(source, isNot(contains("'origin'")));
      expect(source, isNot(contains("'lat': 0")));
      expect(source, isNot(contains("'lng': 0")));
    });
  });
}

Matcher _broadcastFailure(OrderBroadcastFailure failure) =>
    isA<OrderBroadcastException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

Map<String, dynamic> _candidate(Map<String, dynamic> response) =>
    (response['candidates'] as List<dynamic>).single as Map<String, dynamic>;

Map<String, dynamic> _matchingResponse() => <String, dynamic>{
  'requestId': 'req-42',
  'tierId': 'express',
  'radiusKm': 25,
  'notifiedCount': 4,
  'candidateCount': 9,
  'candidates': <Map<String, dynamic>>[
    <String, dynamic>{
      'userId': 'jeeber-1',
      'vehicleType': 'car',
      'distanceKm': 1.2,
      'rating': 4.8,
    },
  ],
  'elapsedMs': 38,
};

final class _MatchingHarness {
  _MatchingHarness(this.response) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: response,
            ),
          );
        },
      ),
    );
  }

  final Map<String, dynamic> response;
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  final List<RequestOptions> requests = [];
}
