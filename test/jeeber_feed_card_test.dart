import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_chip.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_waveform.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_card.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

/// Wraps a feed card in the same themed Scaffold host used by production.
Widget _host(Widget child, {Locale locale = const Locale('en')}) =>
    wrapForTest(Scaffold(body: child), locale: locale);

DeliveryRequest _request({
  String id = 'req-1',
  JeeberFeedItemStatus status = JeeberFeedItemStatus.incoming,
  JeeberDeliveryAction? action,
  DateTime? receivedAt,
  String? senderName = 'Sami Fawaz',
  String? senderAvatarUrl,
  double? senderRating = 4,
  JeeberRequestTier? tier = JeeberRequestTier.flash,
  String? itemsSummary = '1 kilo potato, water gallon, coffee blend',
  double? distanceFromYouKm = 3,
}) {
  return DeliveryRequest(
    id: id,
    pickup: const RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
    dropoff: const RequestLocation(label: 'Verdun', latitude: 0, longitude: 0),
    tier: tier,
    estimatedDistanceKm: 3,
    potentialEarnings: 4,
    currency: 'USD',
    expiresAt: DateTime(2030),
    senderName: senderName,
    senderAvatarUrl: senderAvatarUrl,
    senderRating: senderRating,
    itemsSummary: itemsSummary,
    distanceFromYouKm: distanceFromYouKm,
    receivedAt: receivedAt ?? DateTime(2026, 6, 11, 9, 41),
    feedStatus: status,
    nextDeliveryAction: action,
  );
}

void main() {
  // The board's card leads with the JOB (16 `tpl 931–943`): what was asked for,
  // then tier + distance + neighbourhood. The client's identity is deliberately
  // absent — it is not what the jeeber prices, and it lives on the detail.
  testWidgets('leads with the job, then tier + distance + neighbourhood', (
    tester,
  ) async {
    await tester.pumpWidget(_host(JeeberFeedCard(request: _request())));
    await tester.pumpAndSettle();

    expect(
      find.text('1 kilo potato, water gallon, coffee blend'),
      findsOneWidget,
    );
    expect(find.text('3 km'), findsOneWidget);
    expect(find.text('Hamra'), findsOneWidget);
    expect(find.text('Flash'), findsOneWidget);

    // The identity band is gone, not merely restyled.
    expect(find.text('Sami Fawaz'), findsNothing);
    expect(find.byType(OmdsStarRatingDisplay), findsNothing);
    expect(find.byType(OmdsProfileAvatar), findsNothing);
  });

  testWidgets('unknown tier renders no fabricated tier chip', (tester) async {
    await tester.pumpWidget(
      _host(JeeberFeedCard(request: _request(tier: null), onOffer: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JeebTierChip), findsNothing);
    expect(find.text('Light'), findsNothing);
    expect(find.text('Make offer'), findsOneWidget);
  });

  // A request filed with no description is still a job: the headline falls back
  // to the client's name (and to the localized anonymous label), never to an
  // empty row.
  testWidgets('a request with no description falls back, never blanks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        JeeberFeedCard(
          request: _request(
            itemsSummary: null,
            senderName: null,
            senderRating: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headline = tester.widget<Text>(
      find.byKey(const Key('jeeber-feed-card-summary')),
    );
    expect(headline.data, 'Customer');
  });

  // Structure proof for the two-row content model: the headline sits above the
  // meta row, the timestamp is pinned to the end of row 1, and the CTA is
  // pinned to the end of row 2 — the whole point of the redesign is that a
  // jeeber can scan a column of these without reading them.
  testWidgets('two rows: job + time, then tier + meta + one action', (
    tester,
  ) async {
    // 480, not a handset 360: `flutter_test`'s stand-in font advances every
    // glyph by its full font size (~1.8x Inter), so a 360 surface here models
    // a ~200dp device, not the S22 this row is measured for.
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        JeeberFeedCard(request: _request(), onIgnore: () {}, onOffer: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final headlineRect = tester.getRect(
      find.byKey(const Key('jeeber-feed-card-summary')),
    );
    final timeRect = tester.getRect(
      find.byKey(const Key('jeeber-feed-card-timestamp')),
    );
    final metaRect = tester.getRect(
      find.byKey(const Key('jeeber-feed-card-footer')),
    );
    final offerRect = tester.getRect(
      find.byKey(const Key('jeeber-feed-offer-req-1')),
    );

    // Row 1: headline and time share a baseline band; the time is at the end.
    expect(timeRect.center.dy, closeTo(headlineRect.center.dy, 4));
    expect(timeRect.left, greaterThan(headlineRect.right - 1));
    // Row 2 is below row 1, and the action is its end-most element.
    expect(metaRect.top, greaterThan(headlineRect.bottom));
    expect(offerRect.right, greaterThan(metaRect.center.dx));
    expect(
      find.descendant(
        of: find.byKey(const Key('jeeber-feed-card-footer')),
        matching: find.text('Flash'),
      ),
      findsOneWidget,
    );
  });

  // G1 (sprint-009 P0): the description is the request CONTENT the jeeber
  // prices, so it is the card's HEADLINE. The board gives it one line — the
  // full text lives on the request detail, and a wrapping headline pushed the
  // decision row below the fold.
  testWidgets('the description is the one-line, card-title headline', (
    tester,
  ) async {
    const longDescription =
        '2 shawarma + cola from Barbar, extra garlic, no pickles, and a '
        'large fries — call me when you arrive at the building entrance, '
        'third floor, ring twice';
    await tester.pumpWidget(
      _host(JeeberFeedCard(request: _request(itemsSummary: longDescription))),
    );
    await tester.pumpAndSettle();

    final summary = tester.widget<Text>(
      find.byKey(const Key('jeeber-feed-card-summary')),
    );
    expect(
      summary.data,
      longDescription,
      reason: 'the customer\'s own words render verbatim',
    );
    expect(summary.maxLines, 1);
    expect(summary.overflow, TextOverflow.ellipsis);

    final context = tester.element(
      find.byKey(const Key('jeeber-feed-card-summary')),
    );
    final theme = Theme.of(context);
    // MIDNIGHT: `primary` IS the brand orange, so the headline reads
    // `onSurface` — the orange is rationed to the freshest row's CTA.
    expect(summary.style?.color, theme.colorScheme.onSurface);
  });

  // R5: orange is rationed to the ONE action worth taking right now. The feed
  // marks only its freshest offerable row, so a column of cards sorts itself.
  group('R5 the one action that decays', () {
    testWidgets('the freshest row fills its offer pill with the accent role', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          JeeberFeedCard(request: _request(), onOffer: () {}, isFreshest: true),
        ),
      );
      await tester.pumpAndSettle();

      final pill = tester.widget<JeebCtaButton>(
        find.byKey(const Key('jeeber-feed-offer-req-1')),
      );
      // Wave-A: the kit's own accent variant, not a Theme-swapped `primary`.
      expect(pill.variant, JeebCtaVariant.accent);
    });

    testWidgets('every older row keeps the same pill, outlined', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(JeeberFeedCard(request: _request(), onOffer: () {})),
      );
      await tester.pumpAndSettle();

      final pill = tester.widget<JeebCtaButton>(
        find.byKey(const Key('jeeber-feed-offer-req-1')),
      );
      expect(pill.variant, JeebCtaVariant.outline);
    });

    // doc-13 P1: an EVEN flex split between `Ignore` and the pill starved the
    // CTA into "Make of…". The action area now splits 1:2, so the secondary
    // word yields first. Asserting the SHARE, not a pixel width: the stand-in
    // test font is ~1.8x Inter, so an absolute label width would only prove
    // something about the harness. Fails-without-fix: at 1:1 the two are equal.
    testWidgets('the offer pill outweighs Ignore in the action row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          JeeberFeedCard(request: _request(), onIgnore: () {}, onOffer: () {}),
        ),
      );
      await tester.pumpAndSettle();

      final offer = tester.getSize(
        find.byKey(const Key('jeeber-feed-offer-req-1')),
      );
      final ignore = tester.getSize(
        find.byKey(const Key('jeeber-feed-ignore-req-1')),
      );
      expect(
        offer.width,
        greaterThan(ignore.width * 1.5),
        reason: 'the CTA must take the larger share of the action row',
      );
    });
  });

  // The card is an outlined kit card — never a shadowed one (§1.6
  // outline-over-shadow), so a feed of them reads as one flat column.
  testWidgets('the card is the kit outlined card', (tester) async {
    await tester.pumpWidget(_host(JeeberFeedCard(request: _request())));
    await tester.pumpAndSettle();

    expect(find.byType(JeebOutlinedCard), findsOneWidget);
  });

  // The waveform mark is opt-in and OFF by default: the feed item carries no
  // voice flag, and a guessed mark would misreport how the request was filed.
  group('voice mark', () {
    testWidgets('is absent by default', (tester) async {
      await tester.pumpWidget(_host(JeeberFeedCard(request: _request())));
      await tester.pumpAndSettle();
      expect(find.byType(JeebWaveform), findsNothing);
    });

    testWidgets('renders before the headline when the request is voice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(JeeberFeedCard(request: _request(), isVoice: true)),
      );
      await tester.pumpAndSettle();

      final markRect = tester.getRect(find.byType(JeebWaveform));
      final headlineRect = tester.getRect(
        find.byKey(const Key('jeeber-feed-card-summary')),
      );
      expect(markRect.right, lessThanOrEqualTo(headlineRect.left));
    });
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
    expect(find.text('Make offer'), findsOneWidget);

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
    expect(find.text('Make offer'), findsNothing);
  });

  testWidgets('accepted status shows the delivery-action button', (
    tester,
  ) async {
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

  testWidgets('accepted status renders heading-to-drop-off label', (
    tester,
  ) async {
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
  testWidgets('accepted-action pill is content-hugging (not full-width)', (
    tester,
  ) async {
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

    final pillWidth = tester
        .getSize(find.byKey(const Key('jeeber-feed-action-req-1')))
        .width;
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

  // End-alignment proof: the hugged pill's end edge is flush with the card's
  // tokenized inset (LTR), while the tier stays at the opposite edge.
  //
  // The tolerance is the REAL inset the redesign put there: the 24 page gutter
  // + the kit card's 16 content padding + its 1.5 stroke = 41.5. (Pre-redesign
  // this assertion read `Spacing.threeXLarge` against a 16 gutter and was RED
  // on main at 538.8 — the pill was full-width inside a `Wrap`. The two-row Row
  // is what actually pins it; the constant now matches the board's gutter.)
  testWidgets('accepted-action pill is end-aligned (right-flush in LTR)', (
    tester,
  ) async {
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

    final pillRect = tester.getRect(
      find.byKey(const Key('jeeber-feed-action-req-1')),
    );
    final cardRect = tester.getRect(find.byType(JeeberFeedCard));

    // 24 page gutter + 16 kit-card padding + the card's 1.5 stroke = 41.5.
    const cardInset = Spacing.xLarge + Spacing.medium + 2;
    expect(
      (cardRect.right - pillRect.right).abs(),
      lessThanOrEqualTo(cardInset),
    );
    expect(pillRect.left, greaterThan(cardRect.left + Spacing.xLarge));
  });

  testWidgets('exposes a stable card semantics identifier', (tester) async {
    await tester.pumpWidget(
      _host(JeeberFeedCard(request: _request(), onTap: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Pending')), findsNothing);
    expect(find.byKey(const Key('jeeber-feed-card-req-1')), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('jeeber_feed_request_card_req-1'),
      findsOneWidget,
    );
  });

  testWidgets('renders mirrored under Arabic locale', (tester) async {
    await tester.pumpWidget(
      _host(JeeberFeedCard(request: _request()), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    final dir = Directionality.of(tester.element(find.byType(JeeberFeedCard)));
    expect(dir, TextDirection.rtl);
    expect(find.text('فلاش'), findsOneWidget);
    // The tier label is its own Text — the emoji never concatenates into it.
    expect(find.text('⚡ فلاش'), findsNothing);
  });

  group('G3 graceful expiry state', () {
    testWidgets(
      'expired card dims without a fade, swaps actions for "Expired", and '
      'goes inert',
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
        expect(find.text('Make offer'), findsNothing);
        expect(
          find.bySemanticsIdentifier('jeeber_feed_request_expired_req-1'),
          findsOneWidget,
        );

        // M5: dimmed, not vanished — and dimmed as a STATE. R16/R21 list the
        // expired-row dimming under *does not move*, so no fade transition.
        final dim = tester.widget<Opacity>(
          find.ancestor(
            of: find.byKey(const Key('jeeber-feed-card-req-1')),
            matching: find.byType(Opacity),
          ),
        );
        expect(dim.opacity, UIConstants.opacityDisabled);
        expect(
          find.descendant(
            of: find.byType(JeeberFeedCard),
            matching: find.byType(AnimatedOpacity),
          ),
          findsNothing,
        );

        // Inert: the tap-through is disabled during the linger window.
        await tester.tap(
          find.byKey(const Key('jeeber-feed-card-req-1')),
          warnIfMissed: false,
        );
        expect(tapped, isFalse);
        expect(offered, isFalse);
      },
    );

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
    testWidgets('age is measured against the DEVICE clock, not raw UTC', (
      tester,
    ) async {
      // A UTC instant two hours old, as the gateway parse layer guarantees.
      final utcInstant = DateTime.now().toUtc().subtract(
        const Duration(hours: 2),
      );
      await tester.pumpWidget(
        _host(JeeberFeedCard(request: _request(receivedAt: utcInstant))),
      );
      await tester.pumpAndSettle();

      final stamp = tester.widget<Text>(
        find.byKey(const Key('jeeber-feed-card-timestamp')),
      );
      expect(
        stamp.data,
        '2 h ago',
        reason: 'the card must render the age against the device clock',
      );
      // The pre-fix leak was a wall clock formatted off the raw UTC fields
      // ("09:41" under a 2h-ahead status bar). No clock may survive here.
      expect(
        stamp.data,
        isNot(contains(':')),
        reason: 'the timestamp is a relative age now, never a wall clock',
      );
    });

    testWidgets('a fresh request reads "Just now", not a clock', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          JeeberFeedCard(
            request: _request(receivedAt: DateTime.now().toUtc()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Just now'), findsOneWidget);
    });
  });
}
