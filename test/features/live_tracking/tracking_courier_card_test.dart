// redesign-2026-08 §C task 10 — the matched-courier card on live tracking.
//
// The board (`12-live-tracking.html` tpl 765-773) draws a `★ 4.9` run and a
// Ø40 phone circle beside the courier's name. NEITHER SHIPS, and that is the
// point of this file: `DeliveryTrackingInfo._parseJeeber` never reads `rating`
// or `phoneE164` off the wire (pinned by
// `delivery_tracking_jeeber_parse_test.dart`), because the blind-reveal rule
// keeps both out of the customer's hands until the delivery completes. A future
// lane that "restores the missing star" would be re-opening a privacy hole, so
// the absence is asserted rather than left to a comment.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_courier_card.dart';

import '../../support/sync_app_localizations.dart';

const _withPhoto = JeeberSummary(
  displayName: 'Karim',
  vehicleLabel: 'Scooter',
  avatarUrl: 'https://cdn.jeeb.app/avatars/jeeber-karim-001.jpg',
);

const _withoutPhoto = JeeberSummary(
  displayName: 'Karim',
  vehicleLabel: 'Scooter',
);

void main() {
  testWidgets('renders the on-the-way title and the cash qualifier',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const TrackingCourierCard(
          jeeber: _withoutPhoto,
          price: 8,
          currency: 'USD',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Karim is on the way'), findsOneWidget);
    expect(
      find.text('Scooter · 8.00 USD cash on delivery'),
      findsOneWidget,
    );
  });

  testWidgets('degrades to the vehicle label alone when there is no price',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(const TrackingCourierCard(jeeber: _withoutPhoto)),
    );
    await tester.pump();

    expect(find.text('Scooter'), findsOneWidget);
    expect(find.textContaining('cash on delivery'), findsNothing);
  });

  testWidgets('NO star, NO rating and NO call affordance — the blind-reveal '
      'contract, not a data gap', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapForTest(
        const TrackingCourierCard(
          jeeber: _withPhoto,
          price: 8,
          currency: 'USD',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('★'), findsNothing);
    expect(find.textContaining('4.9'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.phone), findsNothing);
    expect(find.byIcon(Icons.call), findsNothing);
    expect(find.byIcon(Icons.phone_outlined), findsNothing);
    expect(
      find.bySemanticsIdentifier('tracking_courier_call_cta'),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('surfaces tracking_courier_card as its own queryable node',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapForTest(const TrackingCourierCard(jeeber: _withoutPhoto)),
    );
    await tester.pump();

    expect(find.bySemanticsIdentifier('tracking_courier_card'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('paints the photo when a URL exists, the initial disc otherwise',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(const TrackingCourierCard(jeeber: _withPhoto)),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      wrapForTest(const TrackingCourierCard(jeeber: _withoutPhoto)),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    // The honest fallback: the first letter of the display name.
    expect(find.text('K'), findsOneWidget);
  });

  testWidgets('mirrors under Arabic', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const TrackingCourierCard(jeeber: _withoutPhoto),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('Karim في الطريق'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(TrackingCourierCard))),
      TextDirection.rtl,
    );
  });
}
