// JM-026 — Waiting / No-Coverage state (waiting-no-coverage).

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
NoOfferTimeoutScreen _screen(WaitingRequest seed, {DateTime? now}) {
  final fixedNow = now ?? DateTime.utc(2026, 6, 18, 9, 0, 0);
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

/// P7: seeds carry the ANCHOR PAIR (device receive instant + server-relative
/// remaining), not a server absolute. The default pair reproduces the previous
WaitingRequest _broadcast({
  int notified = 4,
  int offers = 0,
  Duration? remaining = const Duration(minutes: 4, seconds: 30),
}) => WaitingRequest(
  requestId: 'req-client-001-pending',
  phase: offers > 0
      ? WaitingRequestPhase.offersArrived
      : WaitingRequestPhase.broadcasting,
  notifiedCount: notified,
  offerCount: offers,
  receivedAt: DateTime.utc(2026, 6, 18, 9),
  remainingAtReceipt: remaining,
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
    testWidgets('AC1 — broadcast state surfaces count + countdown + CTAs', (
      tester,
    ) async {
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
      expect(
        find.bySemanticsIdentifier('waiting_no_coverage_state'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('waiting_review_offers_cta'),
        findsNothing,
      );
    });

    // G1 (sprint-009 P0): the waiting surface echoes the customer's OWN
    testWidgets('G1 — echoes the request content under "Your request"', (
      tester,
    ) async {
      await tester.pumpWidget(wrapForTest(_screen(_broadcast())));
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('waiting_request_description'),
        findsOneWidget,
        reason: 'the customer must see what they asked for while waiting',
      );
      expect(find.text('Your request'), findsOneWidget);
      expect(find.text('Pharmacy run'), findsOneWidget);
    });

    testWidgets(
      'G1 — no echo card when the request row carries no title/description',
      (tester) async {
        final seed = WaitingRequest(
          requestId: 'req-no-title',
          phase: WaitingRequestPhase.broadcasting,
          notifiedCount: 2,
          offerCount: 0,
          receivedAt: DateTime.utc(2026, 6, 18, 9),
          remainingAtReceipt: const Duration(minutes: 4, seconds: 30),
        );
        await tester.pumpWidget(wrapForTest(_screen(seed)));
        await tester.pump();
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('waiting_request_description'),
          findsNothing,
        );
      },
    );

    // BUG-4 / JM-026 false-no-coverage: the gateway never populates
    testWidgets(
      'AC1b — 0 notified within the broadcast window keeps the broadcast '
      'header, never the no-offers-yet state',
      (tester) async {
        await tester.pumpWidget(wrapForTest(_screen(_broadcast(notified: 0))));
        await tester.pump();
        await tester.pump();

        // Broadcast signature node is present (with neutral reassurance copy).
        expect(
          find.bySemanticsIdentifier('waiting_notified_count'),
          findsOneWidget,
        );
        expect(find.bySemanticsIdentifier('waiting_countdown'), findsOneWidget);
        // The no-offers-yet / no-coverage state must NOT appear mid-window.
        expect(
          find.bySemanticsIdentifier('waiting_no_coverage_state'),
          findsNothing,
        );
        // Re-target + cancel remain available so the user is never stuck.
        expect(
          find.bySemanticsIdentifier('waiting_retarget_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('waiting_cancel_cta'),
          findsOneWidget,
        );
      },
    );

    // The ONLY place a no-coverage-style state appears: the offer-wait window
    testWidgets(
      'AC1c — broadcast window elapsed + 0 offers shows the no-offers-yet '
      'state',
      (tester) async {
        // P7: the server itself reports zero remaining — the client no longer
        await tester.pumpWidget(
          wrapForTest(
            _screen(_broadcast(notified: 0, remaining: Duration.zero)),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('waiting_no_coverage_state'),
          findsOneWidget,
        );
        // Broadcast count line is replaced by the no-offers-yet header.
        expect(
          find.bySemanticsIdentifier('waiting_notified_count'),
          findsNothing,
        );
        // Re-target + cancel remain available so the user is never stuck.
        expect(
          find.bySemanticsIdentifier('waiting_retarget_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('waiting_cancel_cta'),
          findsOneWidget,
        );
      },
    );

    // Regression: the contradictory screenshot state (no-coverage header AND a
    testWidgets(
      'AC1d — 0 notified WITH offers shows the review CTA and never the '
      'no-offers-yet state',
      (tester) async {
        // Past the deadline AND offers in: hasOffers must keep the no-offers-yet
        await tester.pumpWidget(
          wrapForTest(
            _screen(
              _broadcast(notified: 0, offers: 2, remaining: Duration.zero),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('waiting_review_offers_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('waiting_no_coverage_state'),
          findsNothing,
        );
      },
    );

    testWidgets('AC2 — offers arrived surfaces the review-offers CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(_screen(_broadcast(notified: 4, offers: 2))),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('waiting_review_offers_cta'),
        findsOneWidget,
      );
    });

    testWidgets(
      'terminal request on entry shows its terminal state and no countdown',
      (tester) async {
        final expired = WaitingRequest(
          requestId: 'E2E-PUSH-2145',
          phase: WaitingRequestPhase.expired,
          notifiedCount: 4,
          offerCount: 0,
          // Even a still-running anchor cannot resurrect a server-terminal row.
          receivedAt: DateTime.utc(2026, 6, 18, 9),
          remainingAtReceipt: const Duration(hours: 1),
          title: 'Dead request',
        );

        await tester.pumpWidget(wrapForTest(_screen(expired)));
        await tester.pump();
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('waiting_terminal_state'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('waiting_terminal_home_cta'),
          findsOneWidget,
        );
        expect(find.text('Request expired'), findsOneWidget);
        expect(find.bySemanticsIdentifier('waiting_countdown'), findsNothing);
        expect(
          find.bySemanticsIdentifier('waiting_notified_count'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('waiting_retarget_cta'),
          findsNothing,
        );
        expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsNothing);
      },
    );

    testWidgets('terminal poll exits the live countdown immediately', (
      tester,
    ) async {
      final pollTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      final repo = _TerminalPollRepository(
        initial: _broadcast(),
        terminal: WaitingRequest(
          requestId: 'req-client-001-pending',
          phase: WaitingRequestPhase.cancelled,
          notifiedCount: 4,
          offerCount: 0,
          receivedAt: DateTime.utc(2026, 6, 18, 9),
          remainingAtReceipt: const Duration(hours: 1),
        ),
      );
      await tester.pumpWidget(
        wrapForTest(
          NoOfferTimeoutScreen(
            requestId: 'req-client-001-pending',
            repository: repo,
            cubitFactory: (r, requestId) => WaitingCubit(
              repository: r,
              requestId: requestId,
              now: () => DateTime.utc(2026, 6, 18, 9),
              refreshSignals: pollTicks.stream,
              clockTicks: const Stream.empty(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsOneWidget);

      pollTicks.add(null);
      await repo.polled;
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('waiting_terminal_state'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsNothing);
      expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsNothing);
    });

    // Regression: the broadcast-state signature ids (`waiting_notified_count` /
    testWidgets('AC1 — count + countdown paint even when the offers read hangs', (
      tester,
    ) async {
      final fixedNow = DateTime.utc(2026, 6, 18, 9, 0, 0);
      final repo = _HangingOffersRepository(_broadcast(notified: 4));
      await tester.pumpWidget(
        wrapForTest(
          NoOfferTimeoutScreen(
            requestId: 'req-client-001-pending',
            repository: repo,
            cubitFactory: (r, requestId) => WaitingCubit(
              repository: r,
              requestId: requestId,
              now: () => fixedNow,
              refreshSignals: const Stream.empty(),
              clockTicks: const Stream.empty(),
            ),
          ),
        ),
      );
      await tester.pump(); // request read resolves
      await tester.pump(); // loaded → first paint (offers read still pending)

      // Broadcast signature ids are up despite the never-resolving offers read.
      expect(
        find.bySemanticsIdentifier('waiting_notified_count'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsOneWidget);
      // Not flipped to the review CTA — the offers signal never arrived.
      expect(
        find.bySemanticsIdentifier('waiting_review_offers_cta'),
        findsNothing,
      );
    });

    // P7 T5.5 — a backend-contract break gets its OWN copy, so a QA run reports
    testWidgets('T5.5 — a contract violation renders the contract-break copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          _errorScreen(
            const WaitingException(
              WaitingFailure.contractViolation,
              'offerDeadlineInSeconds absent on a live broadcasting row',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('waiting_error_state'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your request status came back in an unexpected format. '
          'This is a server problem, not your connection.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "We couldn't load your request status. Please try again.",
        ),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsNothing);
    });

    testWidgets('T5.5 — a network failure keeps the generic connection copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          _errorScreen(const WaitingException(WaitingFailure.network)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          "We couldn't load your request status. Please try again.",
        ),
        findsOneWidget,
      );
    });
  });
}

/// Builds the screen over a repository that always fails with [failure], so the
/// error branch's copy selection can be asserted.
NoOfferTimeoutScreen _errorScreen(WaitingException failure) =>
    NoOfferTimeoutScreen(
      requestId: 'req-client-001-pending',
      repository: FakeWaitingRepository(failure: failure),
      cubitFactory: (repo, requestId) => WaitingCubit(
        repository: repo,
        requestId: requestId,
        now: () => DateTime.utc(2026, 6, 18, 9),
        refreshSignals: const Stream.empty(),
        clockTicks: const Stream.empty(),
      ),
    );

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

class _TerminalPollRepository implements WaitingRepository {
  _TerminalPollRepository({required this.initial, required this.terminal});

  final WaitingRequest initial;
  final WaitingRequest terminal;
  final Completer<void> _polled = Completer<void>();

  Future<void> get polled => _polled.future;

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async => initial;

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    if (!_polled.isCompleted) _polled.complete();
    return terminal;
  }

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) async =>
      fallback;
}
