// N9 — the RESUME BACKSTOP for `NoOfferTimeoutScreen`.
//
// ## The regression these tests pin
//
// The polling→push conversion deleted the ungated 5 s `Stream.periodic` →
// `_poll()` → `fetchWaiting` that drove this screen. That poll was never a
// feature; it was the implicit SELF-HEAL, and nothing replaced it. What was
// left was a screen on which EVERY widget is a `StatelessWidget` — no
// `ResumeRefetchMixin`, no `didChangeAppLifecycleState`, no `RouteAware`, no
// `initState` — whose only non-push fetch is `cubit.load()` inside
// `BlocProvider(create:)` and whose only retry sits on the ERROR state.
//
// A `newOffer` / `request_expired` push that lands while the app is
// BACKGROUNDED never reaches the refresh bus: only
// `FirebaseMessaging.onMessage` publishes to it, the background isolate does
// not, and `app.dart` does not replay a refresh on resume. So a customer who
// returned to the app WITHOUT tapping the notification sat on a permanently
// stale "Finding Jeebers" — while `WaitingCubit.tick()` kept the countdown
// moving, which makes frozen data look live. That is worse than a visibly
// broken screen.
//
// ## Mutation proof
//
// Every widget-level case here fails with `RouteResumeRefetch` removed from
// `no_offer_timeout_screen.dart` — the transcript is recorded in the PR body.
// A test that would still pass without the subject tests nothing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_state.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../../support/sync_app_localizations.dart';

/// `AppResumeSignals` coalesces at a 2 s floor and re-emits on the TRAILING
/// edge. Assertions are taken after pumping past that window so they measure
/// the settled read count instead of racing the timer.
const _resumeSettle = Duration(seconds: 3);

/// A long idle window used as the "no cadence was reintroduced" control. The
/// deleted poll was 5 s, so this is sixty of its ticks.
const _idleWindow = Duration(minutes: 5);

const _requestId = 'req-n9';
final _fixedNow = DateTime.utc(2026, 7, 28, 9);

/// Scripted [WaitingRepository] whose snapshot the test mutates BETWEEN reads —
/// the only way to tell "the screen refetched" from "the screen repainted".
/// Reads can also be held open, to exercise the in-flight latch.
class _ScriptedWaitingRepository implements WaitingRepository {
  WaitingRequestPhase phase = WaitingRequestPhase.broadcasting;
  int offerCount = 0;
  int fetchWaitingCount = 0;
  int fetchRequestCount = 0;
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();

  void release() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  WaitingRequest _build() => WaitingRequest(
    requestId: _requestId,
    phase: phase,
    notifiedCount: 4,
    offerCount: offerCount,
    receivedAt: _fixedNow,
    remainingAtReceipt: const Duration(minutes: 5),
    displayId: 'ORD-N9',
    tier: 'express',
    title: 'Pharmacy run',
  );

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    fetchWaitingCount++;
    await _gate?.future;
    return _build();
  }

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async {
    fetchRequestCount++;
    await _gate?.future;
    return _build();
  }

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) async =>
      offerCount;
}

/// The REAL screen, with only the two seams the existing widget tests use: a
/// scripted repository and a cubit whose clock/push streams are empty, so no
/// wall-clock timer leaks into the headless binding. The resume path under test
/// is production code — nothing about it is stubbed.
Widget _screen(_ScriptedWaitingRepository repository) => wrapForTest(
  // MIDNIGHT: the E2 radar loops ∞ by design (03-MOTION-NOTES), so the
  // `pumpAndSettle` below only terminates under reduce motion.
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: NoOfferTimeoutScreen(
        requestId: _requestId,
        repository: repository,
        cubitFactory: (repo, requestId) => WaitingCubit(
          repository: repo,
          requestId: requestId,
          now: () => _fixedNow,
          refreshSignals: const Stream<void>.empty(),
          clockTicks: const Stream<void>.empty(),
        ),
      ),
    ),
  ),
);

Future<void> _driveToBackground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _driveToForeground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

/// One genuine background → foreground trip, settled.
Future<void> _resume(WidgetTester tester) async {
  await _driveToBackground(tester);
  await _driveToForeground(tester);
  await tester.pump(_resumeSettle);
  await tester.pump();
}

Future<void> _pumpLoaded(
  WidgetTester tester,
  _ScriptedWaitingRepository repository,
) async {
  await tester.pumpWidget(_screen(repository));
  await tester.pumpAndSettle();
  expect(
    find.bySemanticsIdentifier('waiting_notified_count'),
    findsOneWidget,
    reason: 'the broadcast state must be on screen before it can go stale',
  );
}

void main() {
  tearDown(() async {
    // The resume one-shot rides the process-wide `AppResumeSignals` singleton,
    // whose coalescing window and `_sawBackground` latch would otherwise bleed
    // between cases and make a resume refetch look dropped.
    await AppResumeSignals.debugReset();
  });

  group('N9 waiting — resume backstop', () {
    testWidgets(
      'background → foreground on a VISIBLE screen issues exactly ONE refetch '
      'and replaces the stale broadcast state',
      (tester) async {
        final repository = _ScriptedWaitingRepository();
        await _pumpLoaded(tester, repository);
        expect(
          repository.fetchWaitingCount,
          0,
          reason:
              'the cold load uses fetchRequest; fetchWaiting is the re-read',
        );
        expect(
          find.bySemanticsIdentifier('waiting_review_offers_cta'),
          findsNothing,
        );

        // A bid lands while the app is BACKGROUNDED. The push reaches the
        // background isolate, which never touches the refresh bus, so the
        // screen has no way to learn about it — until resume.
        repository.offerCount = 1;
        repository.phase = WaitingRequestPhase.offersArrived;
        await tester.pump();
        expect(
          find.bySemanticsIdentifier('waiting_review_offers_cta'),
          findsNothing,
          reason: 'control: the server-side change is invisible without a read',
        );

        await _resume(tester);

        expect(
          repository.fetchWaitingCount,
          1,
          reason: 'exactly one — not zero (the defect), not two (a stampede)',
        );
        expect(
          find.bySemanticsIdentifier('waiting_review_offers_cta'),
          findsOneWidget,
          reason: 'the customer can now reach the bid the push was about',
        );
      },
    );

    testWidgets(
      'a request that went TERMINAL while backgrounded replaces the frozen '
      '"Finding Jeebers" screen on resume',
      (tester) async {
        final repository = _ScriptedWaitingRepository();
        await _pumpLoaded(tester, repository);

        // `request_expired` fired while the process was away. Before this fix
        // the countdown kept ticking under `WaitingCubit.tick()` on a request
        // that no longer existed — frozen data that looks live.
        repository.phase = WaitingRequestPhase.expired;

        await _resume(tester);

        expect(repository.fetchWaitingCount, 1);
        expect(
          find.bySemanticsIdentifier('waiting_terminal_state'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('waiting_notified_count'),
          findsNothing,
          reason: 'the stale broadcast state is GONE, not merely supplemented',
        );
      },
    );

    testWidgets(
      'a resume while the screen is BURIED reads nothing, and returning pays '
      'exactly ONE',
      (tester) async {
        final repository = _ScriptedWaitingRepository();
        await _pumpLoaded(tester, repository);

        final context = tester.element(find.byType(NoOfferTimeoutScreen));
        // Not awaited: the pushed route outlives this call.
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('offer review')),
          ),
        );
        await tester.pumpAndSettle();

        repository.offerCount = 1;
        repository.phase = WaitingRequestPhase.offersArrived;
        await _resume(tester);

        expect(
          repository.fetchWaitingCount,
          0,
          reason:
              'an invisible surface must not read — same rule the '
              'dashboard card already respects through DeferredRefreshGate',
        );

        Navigator.of(tester.element(find.text('offer review'))).pop();
        await tester.pumpAndSettle();

        expect(
          repository.fetchWaitingCount,
          1,
          reason: 'deferred, not dropped: the debt is paid once on return',
        );
      },
    );

    testWidgets('a rapid background/foreground FLAP costs ONE read, not N', (
      tester,
    ) async {
      final repository = _ScriptedWaitingRepository();
      await _pumpLoaded(tester, repository);

      // Hold the read open so the trailing emission lands INSIDE the first
      // round trip — the exact shape the cubit's in-flight latch exists for.
      repository.hold();
      await _driveToBackground(tester);
      await _driveToForeground(tester);
      await _driveToBackground(tester);
      await _driveToForeground(tester);
      await _driveToBackground(tester);
      await _driveToForeground(tester);
      await tester.pump(_resumeSettle);
      await tester.pump();

      expect(
        repository.fetchWaitingCount,
        1,
        reason:
            'AppResumeSignals collapses the burst; the cubit latch drops '
            'whatever survives it while a read is on the wire',
      );

      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'the backstop introduces NO cadence: five idle minutes cost zero reads',
      (tester) async {
        final repository = _ScriptedWaitingRepository();
        await _pumpLoaded(tester, repository);
        final baseline = repository.fetchRequestCount;

        await tester.pump(_idleWindow);
        await tester.pump();

        expect(
          repository.fetchWaitingCount,
          0,
          reason:
              'the deleted 5 s poll must stay deleted — this is 60 of its '
              'ticks',
        );
        expect(repository.fetchRequestCount, baseline);

        // POSITIVE CONTROL — the same harness and the same seam must be able to
        // produce a read, or the zeros above are a dead fixture, not silence.
        await _resume(tester);
        expect(repository.fetchWaitingCount, 1);
      },
    );
  });

  group('N9 waiting — resume coalescing (cubit level)', () {
    test(
      'two resume events with one fetch IN FLIGHT produce ONE fetch',
      () async {
        final repository = _ScriptedWaitingRepository();
        final cubit = WaitingCubit(
          repository: repository,
          requestId: _requestId,
          now: () => _fixedNow,
          refreshSignals: const Stream<void>.empty(),
          clockTicks: const Stream<void>.empty(),
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.status, WaitingScreenStatus.loaded);
        expect(repository.fetchWaitingCount, 0);

        repository.hold();
        cubit.refreshOnResume();
        await Future<void>.delayed(Duration.zero);
        cubit.refreshOnResume();
        await Future<void>.delayed(Duration.zero);

        expect(
          repository.fetchWaitingCount,
          1,
          reason:
              'the second resume must coalesce onto the read already on the '
              'wire — two overlapping reads can complete out of order and paint '
              'the OLDER snapshot',
        );

        repository.release();
        await Future<void>.delayed(Duration.zero);

        // POSITIVE CONTROL — once the wire is free the next resume DOES read, so
        // the 1 above is coalescing rather than a permanently wedged latch.
        cubit.refreshOnResume();
        await Future<void>.delayed(Duration.zero);
        expect(repository.fetchWaitingCount, 2);
      },
    );

    test(
      'a resume before the cold load resolves does not double-read',
      () async {
        final repository = _ScriptedWaitingRepository();
        final cubit = WaitingCubit(
          repository: repository,
          requestId: _requestId,
          now: () => _fixedNow,
          refreshSignals: const Stream<void>.empty(),
          clockTicks: const Stream<void>.empty(),
        );
        addTearDown(cubit.close);

        repository.hold();
        unawaited(cubit.load());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, WaitingScreenStatus.loading);

        cubit.refreshOnResume();
        await Future<void>.delayed(Duration.zero);

        expect(
          repository.fetchWaitingCount,
          0,
          reason: 'the cold load is already fetching this snapshot',
        );

        repository.release();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, WaitingScreenStatus.loaded);
      },
    );
  });
}
