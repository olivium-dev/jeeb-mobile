import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_courier_card.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_map_surface.dart';

import 'support/sync_app_localizations.dart';

/// Fake repository that resolves synchronously to a fixed snapshot, so the
/// cubit lands in `ready` on the first microtask without sitting on the
/// infinite loading ticker. The cubit is built via BlocProvider.create (owns
/// its own lifecycle) — never BlocProvider.value with a live spinner, which
/// hangs the test binding.
class _FakeRepo implements LiveTrackingRepository {
  _FakeRepo(this.info);

  final DeliveryTrackingInfo info;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      info;
}

// Mirrors the mock's public slice for dlv-golden-001 — avatarUrl present, so
// the card paints the avatar disc via its network-image branch.
const _kamal = JeeberSummary(
  displayName: 'Kamal Hajj',
  vehicleLabel: 'Motorbike',
  avatarUrl: 'https://cdn.jeeb.app/avatars/jeeber-kamal-001.jpg',
);

DeliveryTrackingInfo _info({JeeberSummary? jeeber}) => DeliveryTrackingInfo(
      deliveryId: 'dlv-golden-001',
      // inTransit (not atDoor) so the door-code row — not the OTP card — is
      // the block the courier card must sit above.
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const {},
      distanceLabel: '3 km',
      etaMinutes: 12,
      jeeber: jeeber,
    );

Future<void> _pumpScreen(
  WidgetTester tester,
  DeliveryTrackingInfo info, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    wrapForTest(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: BlocProvider<LiveTrackingCubit>(
          create: (_) => LiveTrackingCubit(
            repository: _FakeRepo(info),
            deliveryId: info.deliveryId,
            refreshSignals: const Stream<void>.empty(),
          ),
          child: LiveTrackingScreen(
            deliveryId: info.deliveryId,
            // No keyless GoogleMap in tests.
            useLiveMap: false,
          ),
        ),
      ),
      locale: locale,
    ),
  );
  // Two pumps: frame 1 = loading; the synchronous fetch resolves on the next
  // microtask and the cubit emits `ready`. Single pump()s (never
  // pumpAndSettle — the loading frame holds a live ticker before `ready`).
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
      'mounts the matched-courier card with avatar between the map and the '
      'door-code row when a jeeber is assigned', (tester) async {
    await _pumpScreen(tester, _info(jeeber: _kamal));

    // The redesigned courier card is mounted...
    final card = find.byType(TrackingCourierCard);
    expect(card, findsOneWidget);

    // ...showing the public slice: the on-the-way line + the vehicle label.
    expect(find.text('Kamal Hajj is on the way'), findsOneWidget);
    expect(find.textContaining('Motorbike'), findsOneWidget);

    // ...the avatar disc paints the network image from the public avatarUrl,
    // scoped inside the courier card so we don't match an unrelated Image.
    expect(
      find.descendant(of: card, matching: find.byType(Image)),
      findsOneWidget,
    );

    // ...and it sits BELOW the map and ABOVE the fact strip in paint order.
    final cardTop = tester.getTopLeft(card).dy;
    final mapTop =
        tester.getTopLeft(find.byKey(TrackingMapSurface.rootKey)).dy;
    final panelTop =
        tester.getTopLeft(find.byKey(DeliveryTrackingPanel.rootKey)).dy;
    expect(mapTop, lessThan(cardTop));
    expect(cardTop, lessThan(panelTop));
  });

  testWidgets(
      'does NOT mount the courier card (no misleading waiting state) when no '
      'jeeber is assigned yet', (tester) async {
    await _pumpScreen(tester, _info(jeeber: null));

    // The card is absent entirely — the screen only mounts it once a jeeber
    // is genuinely assigned, so no "looking for a Jeeber…" placeholder ever
    // shows on an already GPS-streaming delivery.
    expect(find.byType(TrackingCourierCard), findsNothing);

    // The rest of the ready body still renders.
    expect(find.byKey(TrackingMapSurface.rootKey), findsOneWidget);
  });

  // MIDNIGHT R3: the sheet is height-capped and scrolls internally, which is
  // what the pinned header's overflow guard used to protect. Arabic at 200% is
  // the worst case the a11y AC requires.
  testWidgets('the tracking sheet never overflows at 200% text scale (AR)',
      (tester) async {
    tester.view.physicalSize = const Size(411.4, 914.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpScreen(
      tester,
      _info(jeeber: _kamal),
      locale: const Locale('ar'),
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
  });
}
