import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_card.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

/// Wraps a feed card in a Material host (the production tree always sits inside
/// a Scaffold) so the card's `InkWell`/`Ink` find a Material ancestor in tests.
Widget _host(Widget child, {Locale locale = const Locale('en')}) =>
    wrapForTest(Scaffold(body: child), locale: locale);

DeliveryRequest _request({
  String id = 'req-1',
  JeeberFeedItemStatus status = JeeberFeedItemStatus.incoming,
  JeeberDeliveryAction? action,
}) {
  return DeliveryRequest(
    id: id,
    pickup: const RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
    dropoff: const RequestLocation(label: 'Verdun', latitude: 0, longitude: 0),
    tier: JeeberRequestTier.flash,
    estimatedDistanceKm: 3,
    potentialEarnings: 4,
    currency: 'USD',
    expiresAt: DateTime(2030),
    senderName: 'Sami Fawaz',
    senderRating: 4,
    itemsSummary: '1 kilo potato, water gallon, coffee blend',
    distanceFromYouKm: 3,
    receivedAt: DateTime(2026, 6, 11, 9, 41),
    feedStatus: status,
    nextDeliveryAction: action,
  );
}

void main() {
  testWidgets('renders name, summary, distance, tier, rating', (tester) async {
    await tester.pumpWidget(_host(JeeberFeedCard(request: _request())));
    await tester.pumpAndSettle();

    expect(find.text('Sami Fawaz'), findsOneWidget);
    expect(
      find.text('1 kilo potato, water gallon, coffee blend'),
      findsOneWidget,
    );
    expect(find.text('3km away from you'), findsOneWidget);
    expect(find.text('Flash'), findsOneWidget);
    expect(find.byType(OmdsStarRatingDisplay), findsOneWidget);
  });

  testWidgets('incoming status shows Ignore + Offer actions', (tester) async {
    var ignored = false;
    var offered = false;
    await tester.pumpWidget(
      _host(
        JeeberFeedCard(
          request: _request(),
          onIgnore: () => ignored = true,
          onOffer: () => offered = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ignore'), findsOneWidget);
    expect(find.text('Offer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('jeeber-feed-offer-req-1')));
    await tester.tap(find.byKey(const Key('jeeber-feed-ignore-req-1')));
    expect(offered, isTrue);
    expect(ignored, isTrue);
  });

  testWidgets('pendingResponse status shows italic Pending', (tester) async {
    await tester.pumpWidget(
      _host(
        JeeberFeedCard(
          request: _request(status: JeeberFeedItemStatus.pendingResponse),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Ignore'), findsNothing);
    expect(find.text('Offer'), findsNothing);
  });

  testWidgets('accepted status shows the delivery-action button',
      (tester) async {
    await tester.pumpWidget(
      _host(
        JeeberFeedCard(
          request: _request(
            status: JeeberFeedItemStatus.accepted,
            action: JeeberDeliveryAction.orderPicked,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order picked'), findsOneWidget);
  });

  testWidgets('accepted status renders heading-to-drop-off label',
      (tester) async {
    await tester.pumpWidget(
      _host(
        JeeberFeedCard(
          request: _request(
            id: 'req-2',
            status: JeeberFeedItemStatus.accepted,
            action: JeeberDeliveryAction.headingToDropOff,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heading to drop off'), findsOneWidget);
  });

  testWidgets('exposes a stable card semantics identifier', (tester) async {
    await tester.pumpWidget(
      _host(JeeberFeedCard(request: _request(), onTap: () {})),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(RegExp('Pending')),
      findsNothing,
    );
    expect(find.byKey(const Key('jeeber-feed-card-req-1')), findsOneWidget);
  });

  testWidgets('renders mirrored under Arabic locale', (tester) async {
    await tester.pumpWidget(
      _host(
        JeeberFeedCard(request: _request()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    final dir = Directionality.of(
      tester.element(find.byType(JeeberFeedCard)),
    );
    expect(dir, TextDirection.rtl);
    expect(find.text('Sami Fawaz'), findsOneWidget);
    expect(find.text('فلاش'), findsOneWidget);
  });
}
