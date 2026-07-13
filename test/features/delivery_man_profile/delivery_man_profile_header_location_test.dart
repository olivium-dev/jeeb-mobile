// F9 — delivery-man profile header location/availability row.
//
// Guards the "· Available" stray-dot regression: the location + availability
// separator must render ONLY when a location is actually present. With an empty
// location the row shows the availability label alone (no leading separator).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_man_profile_header.dart';

import '../../support/sync_app_localizations.dart';

Widget _header({required String location}) => wrapForTest(
      Scaffold(
        body: DeliveryManProfileHeader(
          name: 'Sami',
          avatarUrl: null,
          isVerified: false,
          rating: 4.8,
          reviewCount: 12,
          location: location,
          isAvailable: true,
        ),
      ),
    );

void main() {
  testWidgets('empty location shows availability WITHOUT a separator dot',
      (tester) async {
    await tester.pumpWidget(_header(location: ''));
    await tester.pumpAndSettle();

    // The availability label stands alone — no leading separator dot.
    expect(find.text('Available'), findsOneWidget);
    // Neither the "· Available" (middle-dot) nor the " . Available" (ARB
    // template period) stray-separator variants may render.
    expect(find.textContaining('· Available'), findsNothing);
    expect(find.textContaining('. Available'), findsNothing);
  });

  testWidgets('blank (whitespace) location is also treated as empty',
      (tester) async {
    await tester.pumpWidget(_header(location: '   '));
    await tester.pumpAndSettle();

    expect(find.text('Available'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('non-empty location joins location + availability with separator',
      (tester) async {
    await tester.pumpWidget(_header(location: 'Riyadh'));
    await tester.pumpAndSettle();

    // ARB template is "{location} . {availability}".
    expect(find.text('Riyadh . Available'), findsOneWidget);
  });
}
