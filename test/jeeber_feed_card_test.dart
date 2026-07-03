import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
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
  DateTime? receivedAt,
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
    receivedAt: receivedAt ?? DateTime(2026, 6, 11, 9, 41),
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

  // G1 (sprint-009 P0): the description is the request CONTENT the jeeber
  // prices — it gets a prominent TWO-line preview in the on-surface role.
  testWidgets(
      'G1: description preview is 2-line, ellipsised, and body-prominent',
      (tester) async {
    const longDescription =
        '2 shawarma + cola from Barbar, extra garlic, no pickles, and a '
        'large fries — call me when you arrive at the building entrance, '
        'third floor, ring twice';
    await tester.pumpWidget(_host(JeeberFeedCard(
      request: DeliveryRequest(
        id: 'req-long',
        pickup:
            const RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
        dropoff:
            const RequestLocation(label: 'Verdun', latitude: 0, longitude: 0),
        tier: JeeberRequestTier.flash,
        estimatedDistanceKm: 3,
        potentialEarnings: 4,
        currency: 'USD',
        expiresAt: DateTime(2030),
        itemsSummary: longDescription,
      ),
    )));
    await tester.pumpAndSettle();

    final summary = tester.widget<Text>(
      find.byKey(const Key('jeeber-feed-card-summary')),
    );
    expect(summary.data, longDescription,
        reason: 'the customer\'s own words render verbatim');
    expect(summary.maxLines, 2,
        reason: 'the card shows a 2-line preview (full text on the detail)');
    expect(summary.overflow, TextOverflow.ellipsis);

    // Prominence: on-surface body style, not the old muted caption.
    final context = tester.element(
      find.byKey(const Key('jeeber-feed-card-summary')),
    );
    final theme = Theme.of(context);
    expect(summary.style?.color, theme.colorScheme.onSurface);
    expect(summary.style?.fontSize, theme.textTheme.bodyMedium?.fontSize);
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

  // Figma 56560:1523 — the accepted-action pill is a content-hugging navy pill
  // pinned to the END, NOT a gutter-to-gutter full-width button. `OmdsLoadingButton`
  // expands to `double.infinity` unless given a tight content-width constraint via
  // `IntrinsicWidth`; without that wrap this assertion fails (pill == card width).
  // Fails-without-fix: removing `IntrinsicWidth` makes pillWidth == cardWidth.
  testWidgets('accepted-action pill is content-hugging (not full-width)',
      (tester) async {
    // Fixed surface so card width is deterministic.
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final pillWidth =
        tester.getSize(find.byKey(const Key('jeeber-feed-action-req-1'))).width;
    final cardWidth = tester.getSize(find.byType(JeeberFeedCard)).width;

    // The pill must hug its label, leaving a clear horizontal gap to the gutter.
    // A full-width pill (the defect) would be ~cardWidth; a hugging pill is far
    // narrower. Guard with a generous margin so the test is robust to font metrics.
    expect(
      pillWidth,
      lessThan(cardWidth * 0.7),
      reason: 'accepted-action pill should hug its content, not fill the card',
    );
  });

  // End-alignment proof: the hugged pill's right edge is flush with the card's
  // content right edge (LTR), confirming `Align(AlignmentDirectional.centerEnd)`.
  testWidgets('accepted-action pill is end-aligned (right-flush in LTR)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final pillRect =
        tester.getRect(find.byKey(const Key('jeeber-feed-action-req-1')));
    final cardRect = tester.getRect(find.byType(JeeberFeedCard));

    // Right edges flush (within card horizontal padding tolerance), and the pill
    // does NOT start at the card's left gutter (so it is not full-width).
    expect((cardRect.right - pillRect.right).abs(), lessThan(24));
    expect(pillRect.left, greaterThan(cardRect.left + 24));
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

  group('G3 graceful expiry state', () {
    testWidgets(
        'expired card fades, swaps actions for "Expired", and goes inert',
        (tester) async {
      var tapped = false;
      var offered = false;
      await tester.pumpWidget(
        _host(
          JeeberFeedCard(
            request: _request(),
            isExpired: true,
            onTap: () => tapped = true,
            onOffer: () => offered = true,
            onIgnore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Action row replaced by the expired status (visible, per-request id).
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Ignore'), findsNothing);
      expect(find.text('Offer'), findsNothing);
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_expired_req-1'),
        findsOneWidget,
      );

      // Faded, not vanished.
      final fade = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const Key('jeeber-feed-card-req-1')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fade.opacity, lessThan(1.0));

      // Inert: the tap-through is disabled during the linger window.
      await tester.tap(find.byKey(const Key('jeeber-feed-card-req-1')),
          warnIfMissed: false);
      expect(tapped, isFalse);
      expect(offered, isFalse);
    });

    testWidgets('expired label is localized in Arabic', (tester) async {
      await tester.pumpWidget(
        _host(
          JeeberFeedCard(request: _request(), isExpired: true),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('منتهي الصلاحية'), findsOneWidget);
    });
  });

  group('SW-03 device-local timestamp', () {
    testWidgets('card time renders in DEVICE-LOCAL time, not raw UTC',
        (tester) async {
      // A UTC instant, as the gateway parse layer now guarantees.
      final utcInstant = DateTime.utc(2026, 6, 11, 9, 41);
      await tester.pumpWidget(
        _host(JeeberFeedCard(request: _request(receivedAt: utcInstant))),
      );
      await tester.pumpAndSettle();

      final localExpected = DateFormat.Hm('en').format(utcInstant.toLocal());
      expect(find.text(localExpected), findsOneWidget,
          reason: 'the card must format the local wall clock');

      // On any host whose zone differs from UTC, the raw-UTC rendering
      // ("09:41" under a 2h-ahead clock — the audit's SW-03 leak) must be
      // GONE. Skipped when the host zone IS UTC (strings coincide).
      final utcRendering = DateFormat.Hm('en').format(utcInstant);
      if (utcRendering != localExpected) {
        expect(find.text(utcRendering), findsNothing,
            reason: 'pre-fix the card rendered raw UTC fields');
      }
    });
  });
}
