// Isolated native UI test — NoOfferTimeoutScreen (waiting-no-coverage, JM-026).
// Mirrors test/features/no_offer_timeout/waiting_screen_test.dart: the screen
// self-provides a ticker-driven WaitingCubit, so the cubitFactory seam injects
// EMPTY poll/clock tick streams (no leaking timers on the on-device binding) and
// a fixed clock. FakeWaitingRepository serves the scripted WaitingRequest.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../support/screen_harness.dart';

NoOfferTimeoutScreen _screen(WaitingRequest seed, {DateTime? now}) {
  final fixedNow = now ?? DateTime.utc(2026, 6, 18, 9, 0, 0);
  return NoOfferTimeoutScreen(
    requestId: seed.requestId,
    repository: FakeWaitingRepository(seed: seed),
    cubitFactory: (repo, requestId) => WaitingCubit(
      repository: repo,
      requestId: requestId,
      now: () => fixedNow,
      pollTicks: const Stream.empty(),
      clockTicks: const Stream.empty(),
    ),
  );
}

WaitingRequest _request({int notified = 4, int offers = 0}) => WaitingRequest(
      requestId: 'req-client-001-pending',
      phase: offers > 0
          ? WaitingRequestPhase.offersArrived
          : WaitingRequestPhase.broadcasting,
      notifiedCount: notified,
      offerCount: offers,
      broadcastExpiresAt: DateTime.utc(2026, 6, 18, 9, 4, 30),
      displayId: 'ORD-501001',
      tier: 'express',
      title: 'Pharmacy run',
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('waiting: broadcast state — count + countdown (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_request(notified: 4)),
      'waiting-no-coverage__broadcast',
    );
  });

  testWidgets('waiting: broadcast window elapsed, no offers (en)',
      (tester) async {
    // now == broadcastExpiresAt so remaining clamps to zero → no-offers-yet.
    await pumpAndShoot(
      tester,
      binding,
      _screen(_request(notified: 0), now: DateTime.utc(2026, 6, 18, 9, 4, 30)),
      'waiting-no-coverage__no-coverage',
    );
  });

  testWidgets('waiting: offers arrived — review CTA (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_request(notified: 4, offers: 2)),
      'waiting-no-coverage__offers-ar',
      locale: const Locale('ar'),
    );
  });
}
