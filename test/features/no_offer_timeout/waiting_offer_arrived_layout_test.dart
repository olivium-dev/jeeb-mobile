// D-W3 — in the offers-arrived state the docked "Review offers" pill grew the
// footer, clipping the YOUR-REQUEST echo card so it read as an overlap
// (wave-2 frame 11-a336b-t+10s.png). The radar now gives that height back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../../support/sync_app_localizations.dart';

/// The A336B, in dp — the handset the wave-2 frames were shot on.
const Size kA336B = Size(412, 915);

NoOfferTimeoutScreen _screen(WaitingRequest seed) {
  final fixedNow = DateTime.utc(2026, 6, 18, 9, 0, 0);
  return NoOfferTimeoutScreen(
    requestId: seed.requestId,
    repository: FakeWaitingRepository(seed: seed),
    cubitFactory: (repo, requestId) => WaitingCubit(
      repository: repo,
      requestId: requestId,
      now: () => fixedNow,
      refreshSignals: const Stream.empty(),
      clockTicks: const Stream.empty(),
    ),
  );
}

WaitingRequest _seed({required int offers}) => WaitingRequest(
  requestId: 'req-dw3',
  phase: offers > 0
      ? WaitingRequestPhase.offersArrived
      : WaitingRequestPhase.broadcasting,
  notifiedCount: 4,
  offerCount: offers,
  receivedAt: DateTime.utc(2026, 6, 18, 9),
  remainingAtReceipt: const Duration(minutes: 4, seconds: 30),
  displayId: 'ORD-501001',
  tier: 'express',
  title: 'Two boxes of painkillers and a bottle of cough syrup from the '
      'pharmacy on the corner, then up to the third floor',
);

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = kA336B;
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  testWidgets('D-W3 — the request echo card clears the review-offers pill on '
      'an A336B', (tester) async {
    await tester.pumpWidget(wrapForTest(_screen(_seed(offers: 2))));
    await tester.pump();
    await tester.pump();

    final card = find.bySemanticsIdentifier('waiting_request_description');
    final cta = find.bySemanticsIdentifier('waiting_review_offers_cta');
    expect(card, findsOneWidget);
    expect(cta, findsOneWidget);

    expect(
      tester.getBottomLeft(card).dy,
      lessThanOrEqualTo(tester.getTopLeft(cta).dy),
      reason: 'the echo card must not be clipped under the docked pill',
    );
  });

  testWidgets('D-W3 — the broadcast state keeps the full-size radar', (
    tester,
  ) async {
    await tester.pumpWidget(wrapForTest(_screen(_seed(offers: 0))));
    await tester.pump();
    await tester.pump();

    expect(
      find.bySemanticsIdentifier('waiting_review_offers_cta'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('waiting_notified_count'), findsOneWidget);
  });
}
