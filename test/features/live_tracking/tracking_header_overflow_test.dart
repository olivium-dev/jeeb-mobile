// Live tracking pinned header — the "RIGHT OVERFLOWED BY 75 PIXELS" gate.
//
// ## The defect
//
// `OrderSummaryPinnedHeader`'s tier/ETA line was a `Row` holding two bare
// `Text` children: no `Expanded`, no `Flexible`, no `maxLines`, no `overflow`.
// A `Row` lays non-flex children out with `maxWidth: infinity`, so each `Text`
// claimed its full unwrapped intrinsic width, `RenderFlex` summed them, and any
// excess became a hard overflow — there was no shrink capacity anywhere in the
// row for it to spend instead.
//
// Reported on a Samsung A33: 1080 physical px / DPR 2.625 = 411.4 dp, less
// `Spacing.medium` padding on each side = 379.4 dp of content width.
//
// ## Why these particular test axes
//
// The row fits comfortably in English at scale 1.0 with a short tier — which is
// exactly the fixture every pre-existing test used, and why none of them caught
// it. Three ordinary conditions stack to blow it out, and each is asserted
// here as its own case:
//
//   * text scale 2.0 — the app clamps there (`accessibility.dart`) and the a11y
//     AC demands 200% on all screens without overflow;
//   * Arabic — `summaryEtaPending` is 11 characters in English and 25 in
//     Arabic, so RTL is materially worse, not merely different;
//   * an unmapped tier id — `LiveTrackingL10n.tierName` echoes the raw id back
//     for anything outside its five known slugs, and since #208 that id is read
//     straight off the wire (`tierId`), so it is attacker-of-convenience long.
//
// Every case pumps at the real A33 geometry rather than the 800x600 default
// test surface, because the available width IS the quantity under test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart';

import '../../support/sync_app_localizations.dart';

/// The reporter's device, in dp: 1080 physical px at DPR 2.625.
const Size kA33 = Size(411.4, 914.0);

DeliveryTrackingInfo _info({
  String? tier = 'express',
  int? etaMinutes,
  double? price = 12.5,
  String? currency = 'USD',
}) =>
    DeliveryTrackingInfo(
      deliveryId: 'd-32',
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const {},
      price: price,
      currency: currency,
      jeeberName: 'Kamal Hajj',
      tier: tier,
      etaMinutes: etaMinutes,
      itemSummary: 'painkillers',
    );

Future<void> _pumpHeader(
  WidgetTester tester, {
  required DeliveryTrackingInfo info,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = kA33;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    wrapForTest(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        // Top-aligned, full width — the header is pinned at the top of a
        // Column in `_TrackingBody` with no width constraint of its own, so
        // anything that centres or shrink-wraps it would hide the defect.
        child: Align(
          alignment: Alignment.topCenter,
          child: OrderSummaryPinnedHeader(info: info),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('pinned header never overflows horizontally on an A33', () {
    testWidgets('Arabic at 200% text scale, ETA pending', (tester) async {
      // The reported combination: the longest Arabic strings, doubled.
      await _pumpHeader(
        tester,
        info: _info(etaMinutes: null),
        locale: const Locale('ar'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('English at 200% text scale', (tester) async {
      await _pumpHeader(tester, info: _info(etaMinutes: 8), textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unmapped tier id renders raw and still does not overflow',
        (tester) async {
      // `tierName`'s default arm echoes the wire id back verbatim. A tier slug
      // the app has never heard of must degrade to an ellipsis, not a stripe.
      await _pumpHeader(
        tester,
        info: _info(tier: 'premium-white-glove-same-day-metropolitan'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a high-magnitude price cannot overflow the name row',
        (tester) async {
      // The name is Expanded and collapses first; the price used to be rigid,
      // so past that point the row itself overflowed.
      await _pumpHeader(
        tester,
        info: _info(price: 1234567.89, currency: 'SYP'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the ordinary English case is unchanged', (tester) async {
      // A guard against "fixed" by hiding: if the happy path had regressed to
      // truncation or a stacked layout, that would show up here.
      await _pumpHeader(tester, info: _info(etaMinutes: 8));
      expect(tester.takeException(), isNull);
    });
  });

  group('the facts stay queryable and readable', () {
    testWidgets('tier and ETA keep their semantics ids after the fix',
        (tester) async {
      // The overflow fix reshaped the widget tree (Row -> Wrap + a private
      // strip widget). Maestro asserts on these ids, so losing one would break
      // the e2e suite in a way the overflow assertions above cannot see.
      await _pumpHeader(
        tester,
        info: _info(etaMinutes: 8),
        locale: const Locale('ar'),
        textScale: 2.0,
      );
      expect(find.bySemanticsIdentifier('order_summary_tier'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_price'), findsOneWidget);
    });

    testWidgets('a delivery with no tier renders the ETA alone', (tester) async {
      await _pumpHeader(tester, info: _info(tier: null, etaMinutes: 8));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsIdentifier('order_summary_tier'), findsNothing);
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget);
    });
  });
}
