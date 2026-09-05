// UX-34 / UX-35: an unreadable offer probe says "unknown", never a fabricated
// zero; and a background refresh only raises the warm band on the SECOND
// consecutive failure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_state.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

final DateTime _clock = DateTime.utc(2026, 6, 18, 9);

WaitingRequest _seed({int offerCount = 0}) => WaitingRequest(
  requestId: 'REQ-1',
  phase: WaitingRequestPhase.broadcasting,
  notifiedCount: 6,
  offerCount: offerCount,
  receivedAt: _clock,
  remainingAtReceipt: const Duration(minutes: 3),
  displayId: 'ORD-5001',
  tier: 'express',
  title: '2 grocery bags',
);

/// The probe is unreadable; `fetchWaiting` reports the count as unprobed.
class _CountUnavailable implements WaitingRepository {
  _CountUnavailable();

  int probes = 0;

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async => _seed();

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async =>
      _seed().copyWith(offerCountIsProbed: false);

  @override
  Future<int?> fetchOfferCount(String requestId) async {
    probes++;
    return null;
  }
}

/// `fetchWaiting` throws every time — the push/resume refresh path.
class _RefreshThrows implements WaitingRepository {
  _RefreshThrows();

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async => _seed();

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async =>
      throw const WaitingException(WaitingFailure.network);

  @override
  Future<int?> fetchOfferCount(String requestId) async => 0;
}

/// `fetchWaiting` throws until [healed] flips.
class _HealsOnSecondRead implements WaitingRepository {
  _HealsOnSecondRead();

  bool healed = false;

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async => _seed();

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    if (healed) return _seed();
    throw const WaitingException(WaitingFailure.network);
  }

  @override
  Future<int?> fetchOfferCount(String requestId) async => 0;
}

WaitingCubit _cubit(WaitingRepository repo) => WaitingCubit(
  repository: repo,
  requestId: 'REQ-1',
  now: () => _clock,
  refreshSignals: const Stream<void>.empty(),
  clockTicks: const Stream<void>.empty(),
);

void main() {
  test('an unreadable probe marks the count UNKNOWN, never 0', () async {
    final _CountUnavailable repo = _CountUnavailable();
    final WaitingCubit cubit = _cubit(repo);
    addTearDown(cubit.close);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(repo.probes, greaterThan(0));
    expect(cubit.state.offerCountUnavailable, isTrue);
    expect(cubit.state.refreshError, isNull);
  });

  test('one background failure is noise; two raise the warm band', () async {
    final WaitingCubit cubit = _cubit(_RefreshThrows());
    addTearDown(cubit.close);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    cubit.refreshOnResume();
    await Future<void>.delayed(Duration.zero);
    expect(
      cubit.state.refreshError,
      isNull,
      reason: 'a single blip must not shout at the user',
    );

    cubit.refreshOnResume();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.refreshError, isNotNull);

    cubit.acknowledgeRefreshError();
    expect(cubit.state.refreshError, isNull);
  });

  // R6: the warm band's Retry re-reads in place. `retry()` (the COLD rung's
  // CTA) is the only path that may blank the request.
  test('refresh() keeps the request and never flips to loading', () async {
    final _HealsOnSecondRead repo = _HealsOnSecondRead();
    final WaitingCubit cubit = _cubit(repo);
    addTearDown(cubit.close);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, WaitingScreenStatus.loaded);

    cubit.refreshOnResume();
    await Future<void>.delayed(Duration.zero);
    cubit.refreshOnResume();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.refreshError, isNotNull);

    repo.healed = true;
    final List<WaitingScreenStatus> seen = <WaitingScreenStatus>[];
    final sub = cubit.stream.listen((s) => seen.add(s.status));
    addTearDown(sub.cancel);

    await cubit.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(seen, isNot(contains(WaitingScreenStatus.loading)));
    expect(seen, isNot(contains(WaitingScreenStatus.initial)));
    expect(cubit.state.status, WaitingScreenStatus.loaded);
    expect(cubit.state.request, isNotNull);
    expect(cubit.state.refreshError, isNull);
  });

  test('retry() is still the cold path: it rebuilds from scratch', () async {
    final _HealsOnSecondRead repo = _HealsOnSecondRead()..healed = true;
    final WaitingCubit cubit = _cubit(repo);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.request, isNotNull);

    final List<WaitingScreenStatus> seen = <WaitingScreenStatus>[];
    final sub = cubit.stream.listen((s) => seen.add(s.status));
    addTearDown(sub.cancel);

    await cubit.retry();
    expect(seen, contains(WaitingScreenStatus.initial));
    expect(cubit.state.status, WaitingScreenStatus.loaded);
  });

  for (final Locale locale in kFailureLocales) {
    testWidgets('${locale.languageCode}: the unknown-count note renders', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final _CountUnavailable repo = _CountUnavailable();
      await tester.pumpWidget(
        wrapMidnight(
          NoOfferTimeoutScreen(
            requestId: 'REQ-1',
            repository: repo,
            cubitFactory: (WaitingRepository r, String id) => _cubit(r),
          ),
          locale: locale,
          scrollable: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('waiting_offer_count_unavailable'),
        findsOneWidget,
      );
    });
  }
}
