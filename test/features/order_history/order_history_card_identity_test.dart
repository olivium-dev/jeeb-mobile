// F4b regression lock — device run, 30-cancelled-tab.xml: four Cancelled cards
// all read `Order <full uuid>` and `Current location`, so they are physically
// indistinguishable. GET /v1/requests carries `title` and `displayId` per row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_card.dart';

import '../../support/sync_app_localizations.dart';

/// The exact wire row observed on device for the F8 probe request.
OrderSummary _wireOrder({
  String id = 'defb1f07-efa5-4b8f-bc1a-09d6fcd1140b',
  String displayId = 'defb1f07',
  String title = 'F8-resolve-probe-parcel',
}) => OrderSummary(
  id: id,
  displayId: displayId,
  title: title,
  createdAt: DateTime.utc(2026, 9, 5, 11, 21),
  pickupAddress: 'Current location',
  dropoffAddress: 'Current location',
  status: OrderRequestStatus.cancelled,
  tier: OrderTier.standard,
  amountMinor: null,
  currency: 'USD',
);

Future<void> _pump(
  WidgetTester tester,
  OrderSummary order, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    wrapForTest(
      Scaffold(body: OrderHistoryCard(order: order, onTap: () {})),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

String _cardLabel(WidgetTester tester) =>
    tester.widget<JeebOutlinedCard>(find.byType(JeebOutlinedCard)).semanticLabel!;

void main() {
  testWidgets('card is TITLED by the request title, not the pickup address', (
    tester,
  ) async {
    await _pump(tester, _wireOrder());

    expect(find.text('F8-resolve-probe-parcel'), findsOneWidget);
    expect(find.text('Current location'), findsNothing);
  });

  testWidgets('card is LABELLED by displayId, never the raw uuid', (
    tester,
  ) async {
    await _pump(tester, _wireOrder());

    expect(_cardLabel(tester), 'Order defb1f07');
    expect(_cardLabel(tester), isNot(contains('efa5-4b8f')));
  });

  testWidgets('AR: title and displayId carry through the Arabic label', (
    tester,
  ) async {
    await _pump(tester, _wireOrder(), locale: const Locale('ar'));

    expect(find.text('F8-resolve-probe-parcel'), findsOneWidget);
    expect(_cardLabel(tester), 'الطلب defb1f07');
  });

  testWidgets('the four device Cancelled rows are all distinguishable', (
    tester,
  ) async {
    const List<(String, String, String)> rows = <(String, String, String)>[
      ('defb1f07-efa5-4b8f-bc1a-09d6fcd1140b', 'defb1f07', 'F8-resolve-probe-parcel'),
      ('dc5d0f2e-677f-4520-b9d2-e94510761c50', 'dc5d0f2e', 'validation test parcel'),
      ('f26b3601-9d2f-4b1f-b80c-c5d9120615c6', 'f26b3601', 'Two boxes of panadol from the pharmacy'),
      ('8a87f41f-0aee-4163-8890-bee34765a836', 'ORD-65A836', 'Deliver 2kg of parcels'),
    ];
    final Set<String> labels = <String>{};
    for (final (String id, String displayId, String title) in rows) {
      await _pump(
        tester,
        _wireOrder(id: id, displayId: displayId, title: title),
      );
      labels.add(_cardLabel(tester));
      expect(find.text(title), findsOneWidget);
    }

    expect(labels.length, rows.length);
    expect(labels, contains('Order ORD-65A836'));
  });

  testWidgets('no displayId on the wire → the id is still the label', (
    tester,
  ) async {
    await _pump(tester, _wireOrder(displayId: ''));

    expect(_cardLabel(tester), 'Order defb1f07-efa5-4b8f-bc1a-09d6fcd1140b');
  });

  testWidgets('no title on the wire → the pickup address still titles the row', (
    tester,
  ) async {
    await _pump(tester, _wireOrder(title: ''));

    expect(find.text('Current location'), findsOneWidget);
  });
}
