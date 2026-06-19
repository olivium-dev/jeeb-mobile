// JM-026 — Waiting / No-Coverage state (waiting-no-coverage).
//
// Proves, against the real ARBs + OMDS theme, that:
//   AC1  (broadcast): `waiting_notified_count` + `waiting_countdown` render, and
//        the re-target + cancel CTAs are present.
//   AC1b (no-coverage): a 0-notified snapshot shows `waiting_no_coverage_state`
//        and NOT `waiting_notified_count`.
//   AC2  (offers arrived): an offers-arrived snapshot shows
//        `waiting_review_offers_cta`.
//
// The screen self-provides a ticker-driven WaitingCubit; the test injects the
// `cubitFactory` seam with EMPTY poll/clock tick streams so no real
// `Stream.periodic` timer leaks into the headless binding (mirrors how the
// client_offers widget tests drive ClientOffersCubit). Nav edges (review →
// offer-review, retarget → request-type, cancel → sheet) require a router and
// are asserted by the jm-026 Maestro flow, not here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../../support/sync_app_localizations.dart';

/// Builds the screen with a deterministic cubit: the scripted [repository]
/// snapshot + empty tick streams (no leaking timers). The injected clock is
/// fixed so the countdown is stable.
NoOfferTimeoutScreen _screen(WaitingRequest seed) {
  final fixedNow = DateTime.utc(2026, 6, 18, 9, 0, 0);
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

WaitingRequest _broadcast({int notified = 4, int offers = 0}) => WaitingRequest(
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
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('JM-026 waiting / no-coverage screen', () {
    testWidgets('AC1 — broadcast state surfaces count + countdown + CTAs',
        (tester) async {
      await tester.pumpWidget(wrapForTest(_screen(_broadcast(notified: 4))));
      await tester.pump(); // schedule the async fake load
      await tester.pump(); // loaded → first paint

      for (final id in const [
        'waiting_notified_count',
        'waiting_countdown',
        'waiting_retarget_cta',
        'waiting_cancel_cta',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id must surface as its own SemanticsNode.',
        );
      }
      // No-coverage variant and review CTA are absent in the healthy broadcast.
      expect(find.bySemanticsIdentifier('waiting_no_coverage_state'),
          findsNothing);
      expect(find.bySemanticsIdentifier('waiting_review_offers_cta'),
          findsNothing);
    });

    testWidgets('AC1b — 0 notified shows the no-coverage variant',
        (tester) async {
      await tester.pumpWidget(wrapForTest(_screen(_broadcast(notified: 0))));
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsIdentifier('waiting_no_coverage_state'),
          findsOneWidget);
      // The broadcast count line is replaced by the no-coverage header.
      expect(find.bySemanticsIdentifier('waiting_notified_count'), findsNothing);
      // Re-target + cancel remain available so the user is never stuck.
      expect(find.bySemanticsIdentifier('waiting_retarget_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsOneWidget);
    });

    testWidgets('AC2 — offers arrived surfaces the review-offers CTA',
        (tester) async {
      await tester.pumpWidget(
        wrapForTest(_screen(_broadcast(notified: 4, offers: 2))),
      );
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsIdentifier('waiting_review_offers_cta'),
          findsOneWidget);
    });

    // Regression: the broadcast-state signature ids (`waiting_notified_count` /
    // `waiting_countdown`) must NOT be gated behind the offers read. On device
    // the cold load makes two reads; if the second (offers) read stalls, the
    // count + countdown must still paint from the first (request) read. This is
    // the screen-side root cause of jm-026 RED in 64_W1_QA_RESULTS.
    testWidgets('AC1 — count + countdown paint even when the offers read hangs',
        (tester) async {
      final fixedNow = DateTime.utc(2026, 6, 18, 9, 0, 0);
      final repo = _HangingOffersRepository(
        _broadcast(notified: 4),
      );
      await tester.pumpWidget(
        wrapForTest(
          NoOfferTimeoutScreen(
            requestId: 'req-client-001-pending',
            repository: repo,
            cubitFactory: (r, requestId) => WaitingCubit(
              repository: r,
              requestId: requestId,
              now: () => fixedNow,
              pollTicks: const Stream.empty(),
              clockTicks: const Stream.empty(),
            ),
          ),
        ),
      );
      await tester.pump(); // request read resolves
      await tester.pump(); // loaded → first paint (offers read still pending)

      // Broadcast signature ids are up despite the never-resolving offers read.
      expect(find.bySemanticsIdentifier('waiting_notified_count'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsOneWidget);
      // Not flipped to the review CTA — the offers signal never arrived.
      expect(find.bySemanticsIdentifier('waiting_review_offers_cta'),
          findsNothing);
    });
  });
}

/// Resolves the request read normally but NEVER completes the offers read, so a
/// test can prove the broadcast state paints without waiting on offers.
class _HangingOffersRepository implements WaitingRepository {
  _HangingOffersRepository(this._snapshot);

  final WaitingRequest _snapshot;

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async => _snapshot;

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async => _snapshot;

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) =>
      Completer<int>().future; // never completes
}
