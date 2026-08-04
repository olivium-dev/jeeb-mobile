// Live tracking pinned header — the "RIGHT OVERFLOWED BY 75 PIXELS" gate.

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
      await _pumpHeader(
        tester,
        info: _info(price: 1234567.89, currency: 'SYP'),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the ordinary English case is unchanged', (tester) async {
      // A guard against "fixed" by hiding: if the happy path had regressed to
      await _pumpHeader(tester, info: _info(etaMinutes: 8));
      expect(tester.takeException(), isNull);
    });
  });

  group('the facts stay queryable and readable', () {
    testWidgets('tier and ETA keep their semantics ids after the fix',
        (tester) async {
      // The overflow fix reshaped the widget tree (Row -> Wrap + a private
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
