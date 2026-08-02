import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_jeeber_card.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';

import 'support/sync_app_localizations.dart';

/// Fake repository that resolves synchronously to a fixed snapshot, so the
/// cubit lands in `ready` on the first microtask without sitting on the
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
const _kamal = JeeberSummary(
  displayName: 'Kamal Hajj',
  vehicleLabel: 'Motorbike',
  avatarUrl: 'https://cdn.jeeb.app/avatars/jeeber-kamal-001.jpg',
);

DeliveryTrackingInfo _info({JeeberSummary? jeeber}) => DeliveryTrackingInfo(
      deliveryId: 'dlv-golden-001',
      // inTransit (not atDoor) so the stepper panel — not the OTP card — is the
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const {},
      distanceLabel: '3 km',
      etaMinutes: 12,
      jeeber: jeeber,
    );

Future<void> _pumpScreen(WidgetTester tester, DeliveryTrackingInfo info) async {
  await tester.pumpWidget(
    wrapForTest(
      BlocProvider<LiveTrackingCubit>(
        create: (_) => LiveTrackingCubit(
          repository: _FakeRepo(info),
          deliveryId: info.deliveryId,
          refreshSignals: const Stream<void>.empty(),
        ),
        child: LiveTrackingScreen(deliveryId: info.deliveryId),
      ),
    ),
  );
  // Two pumps: frame 1 = loading; the synchronous fetch resolves on the next
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
      'mounts the matched-Jeeber card with avatar above the stepper when '
      'a jeeber is assigned', (tester) async {
    await _pumpScreen(tester, _info(jeeber: _kamal));

    // The reused DeliveryJeeberCard is mounted...
    final card = find.byKey(DeliveryJeeberCard.rootKey);
    expect(card, findsOneWidget);

    // ...showing the public slice: display name + vehicle label.
    expect(find.text('Kamal Hajj'), findsOneWidget);
    expect(find.text('Motorbike'), findsOneWidget);

    // ...the avatar disc paints the network image from the public avatarUrl,
    expect(
      find.descendant(of: card, matching: find.byType(Image)),
      findsOneWidget,
    );

    // ...and it sits ABOVE the stepper panel in paint order (smaller dy).
    final cardTop = tester.getTopLeft(card).dy;
    final panelTop =
        tester.getTopLeft(find.byKey(DeliveryTrackingPanel.rootKey)).dy;
    expect(cardTop, lessThan(panelTop));
  });

  testWidgets(
      'does NOT mount the Jeeber card (no misleading waiting state) when no '
      'jeeber is assigned yet', (tester) async {
    await _pumpScreen(tester, _info(jeeber: null));

    // The card is absent entirely — the screen only mounts it once a jeeber
    expect(find.byKey(DeliveryJeeberCard.rootKey), findsNothing);

    // The stepper panel still renders (the screen is in its ready state).
    expect(find.byKey(DeliveryTrackingPanel.rootKey), findsOneWidget);
  });
}
