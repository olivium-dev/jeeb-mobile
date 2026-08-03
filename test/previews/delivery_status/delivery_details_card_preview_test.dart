// Render tests for the DeliveryDetailsCard previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_details_card.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryDetailsCard',
    const <String, Widget Function()>{
      'Minimal (no sub-lines)': deliveryDetailsCardMinimal,
      'Sub-lines on both legs': deliveryDetailsCardWithDetails,
      'Pickup-truck tier': deliveryDetailsCardPickupTruckTier,
      'Unresolved pickup': deliveryDetailsCardUnresolvedPickup,
      'Longest content': deliveryDetailsCardLongContent,
      'Arabic addresses in EN UI': deliveryDetailsCardArabicAddresses,
    },
    expectedText: const <String, String>{
      'Minimal (no sub-lines)': 'Hamra',
      'Sub-lines on both legs': 'Costa Coffee, ground floor',
      'Pickup-truck tier': 'Jounieh, Old Souk',
      'Unresolved pickup': 'Mar Mikhael, Beirut',
      'Longest content': 'Sin El Fil, Horch Tabet, Boulevard Camille Chamoun',
      'Arabic addresses in EN UI': 'شارع الحمرا، بيروت',
    },
  );

  group('DeliveryDetailsCard preview specifics', () {
    testWidgets('the tier row shows the tier label, not the pickup label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailsCardPickupTruckTier);

      // "Pickup" (deliveryPickupLabel) heads the first row; "Pickup truck"
      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Pickup truck'), findsOneWidget);
    });

    testWidgets('an empty sub-line is dropped, an empty address line is not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryDetailsCardUnresolvedPickup);

      // `secondary` is guarded by `isNotEmpty`, so the drop-off's '' sub-line
      expect(find.text(''), findsOneWidget);
      // The pickup's sub-line still renders: only the EMPTY one was dropped.
      expect(find.text('Awaiting geocode'), findsOneWidget);
    });

    testWidgets('nothing overflows at the sizes the previews declare', (
      WidgetTester tester,
    ) async {
      // The two box constants encode measured heights. Re-render the tallest
      tester.view.physicalSize = const Size(390, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, deliveryDetailsCardLongContent);

      expect(tester.takeException(), isNull);
    });
  });
}
