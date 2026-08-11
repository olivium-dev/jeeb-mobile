// D-W1: the feed tier chip could never render — `tierId` (a UUID since the
// delivery-service cutover) shadowed the `tier` slug, so _parseTier returned
// null and jeeber_feed_card's `request.tier != null` gate never opened.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_chip.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_card.dart';

import '../../support/sync_app_localizations.dart';

class _MockDio extends Mock implements Dio {}

/// A live gateway tierId — a UUIDv5, never a slug.
const String kTierUuid = '3f2b1c8a-9d44-5e07-b1aa-6c0e2d7f4b91';

Map<String, dynamic> _feedItem({String? tier, String? tierId = kTierUuid}) => {
  'requestId': 'req-dw1',
  'title': 'Painkillers from the pharmacy',
  'pickup': {'label': 'Hamra', 'latitude': 33.89, 'longitude': 35.48},
  'dropoff': {'label': 'Verdun', 'latitude': 33.88, 'longitude': 35.49},
  'tier': ?tier,
  'tierId': ?tierId,
  'potentialEarnings': 6.0,
};

Future<List<DeliveryRequest>> _refreshWith(Map<String, dynamic> item) async {
  final dio = _MockDio();
  when(() => dio.get<dynamic>(any())).thenAnswer(
    (_) async => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [item],
      },
      statusCode: 200,
    ),
  );
  return DioRequestFeedRepository(dio: dio).refresh();
}

void main() {
  group('D-W1 parse rung — the slug wins over the raw tierId', () {
    test('tier slug beside a UUID tierId parses to the tier', () async {
      final requests = await _refreshWith(
        _feedItem(tier: 'standard'),
      );

      expect(requests.single.tier, JeeberRequestTier.standard);
    });

    test('flash slug parses even though tierId is present', () async {
      final requests = await _refreshWith(_feedItem(tier: 'flash'));

      expect(requests.single.tier, JeeberRequestTier.flash);
    });

    test('old gateway (tierId only, no slug) still degrades to null, '
        'not to a crash', () async {
      final requests = await _refreshWith(_feedItem());

      expect(requests.single.tier, isNull);
    });
  });

  testWidgets('D-W1 render rung — the chip builds for a slug-bearing item', (
    tester,
  ) async {
    final requests = await _refreshWith(_feedItem(tier: 'standard'));

    await tester.pumpWidget(
      wrapForTest(
        Scaffold(body: JeeberFeedCard(request: requests.single)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JeebTierChip), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
  });
}
