import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/features/tier_selection/presentation/tier_selection_screen.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

void main() {
  group('TierSelectionScreen', () {
    testWidgets('renders 3 tier cards when API succeeds', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(repository: FakeTierRepository()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(TierSelectionScreen.cardKey(TierId.flash)),
        findsOneWidget,
      );
      expect(
        find.byKey(TierSelectionScreen.cardKey(TierId.express)),
        findsOneWidget,
      );
      expect(
        find.byKey(TierSelectionScreen.cardKey(TierId.standard)),
        findsOneWidget,
      );
    });

    testWidgets('surfaces an error state when network fails (JEBV4-300)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(
            repository: FakeTierRepository(failWith: TierLoadFailure.network),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // JEBV4-300: no fallback catalog is served — no tier cards render, so no
      expect(
        find.byKey(TierSelectionScreen.cardKey(TierId.flash)),
        findsNothing,
      );
      // No cached banner — the failure is surfaced as a retryable error state.
      expect(
        find.byKey(const Key('tier-selection-cached-banner')),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('tier_selection_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('tier_selection_retry_cta'),
        findsOneWidget,
      );
    });

    // F13/ES-21: a 200 with no tiers is EMPTY, not an error, and Confirm must
    // not sit enabled-looking over a list nothing can be picked from.
    testWidgets('a 200 with zero tiers renders the empty rung, not the error '
        'rung, and Confirm stays out of reach', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(repository: _EmptyCatalogueRepository()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('tier_selection_empty'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('tier_selection_error'), findsNothing);
      expect(find.byKey(TierSelectionScreen.confirmButtonKey), findsNothing);
    });

    // F19/COPY-09: a 403 must not render the connectivity body.
    testWidgets('a 403 renders a DIFFERENT body from an offline failure',
        (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(
            repository: _ThrowingRepository(ForbiddenFailure()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('tier_selection_error'),
        findsOneWidget,
      );
      expect(find.textContaining('connection'), findsNothing);
      // Not retryable → an exit, never an inert Retry.
      expect(
        find.bySemanticsIdentifier('tier_selection_retry_cta'),
        findsNothing,
      );
    });

    // F20: a parser bug used to be reported as "check your connection".
    testWidgets('a parse failure is NOT reported as a connectivity problem',
        (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(
            repository: _ThrowingRepository(UnknownFailure(parse: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('tier_selection_error'),
        findsOneWidget,
      );
      expect(find.textContaining('connection'), findsNothing);
    });

    testWidgets('confirm button is disabled until a tier is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(repository: _NoRecommendedRepository()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // No customer tap → nothing selected → button disabled.
      final btn = tester.widget<OmdsPrimaryButton>(
        find.byKey(TierSelectionScreen.confirmButtonKey),
      );
      expect(btn.isEnabled, isFalse);
    });

    testWidgets('tapping a card selects it and enables confirm (AC2)', (
      tester,
    ) async {
      Tier? confirmed;
      await tester.pumpWidget(
        wrapForTest(
          TierSelectionScreen(
            repository: const _NoRecommendedRepository(),
            onConfirmed: (t) => confirmed = t,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(TierSelectionScreen.cardKey(TierId.express)));
      await tester.pump();

      final btn = tester.widget<OmdsPrimaryButton>(
        find.byKey(TierSelectionScreen.confirmButtonKey),
      );
      expect(btn.isEnabled, isTrue);

      await tester.tap(find.byKey(TierSelectionScreen.confirmButtonKey));
      await tester.pump();
      expect(confirmed?.id, TierId.express);
    });

    testWidgets('pre-selects the recommended tier on first load', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(repository: FakeTierRepository()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // MIDNIGHT R9 / doc-13 P0-4: the board loads with a row already lit.
      final btn = tester.widget<OmdsPrimaryButton>(
        find.byKey(TierSelectionScreen.confirmButtonKey),
      );
      expect(btn.isEnabled, isTrue);
    });

    testWidgets('retry button re-fetches and recovers to loaded (JEBV4-300)', (
      tester,
    ) async {
      var callCount = 0;
      await tester.pumpWidget(
        wrapForTest(
          TierSelectionScreen(
            repository: _CountingFakeRepository(
              onFetch: () {
                callCount++;
                if (callCount == 1) {
                  throw const TierLoadException(TierLoadFailure.network);
                }
                return FakeTierRepository.defaultCatalog;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // First load fails → error state with a Retry action (no cached banner).
      expect(
        find.bySemanticsIdentifier('tier_selection_error'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('tier-selection-cached-banner')),
        findsNothing,
      );

      // Tapping Retry re-runs GET /tiers; the second fetch succeeds → loaded.
      final retry = find.bySemanticsIdentifier('tier_selection_retry_cta');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pump();
      await tester.pump();

      expect(callCount, 2);
      expect(find.bySemanticsIdentifier('tier_selection_error'), findsNothing);
      expect(
        find.byKey(TierSelectionScreen.cardKey(TierId.flash)),
        findsOneWidget,
      );
    });
  });
}

/// A 200 that answers with no tiers at all.
class _EmptyCatalogueRepository implements TierRepository {
  const _EmptyCatalogueRepository();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

/// Raises a classified failure, so the copy family's branch is exercised.
class _ThrowingRepository implements TierRepository {
  const _ThrowingRepository(this.failure);

  final AppFailure failure;

  @override
  Future<List<Tier>> fetchTiers() async => throw failure;
}

/// Repository that returns only Express, with no recommended flag.
/// Used to test that the confirm button starts disabled.
class _NoRecommendedRepository implements TierRepository {
  const _NoRecommendedRepository();

  @override
  Future<List<Tier>> fetchTiers() async => const [
    Tier(
      id: TierId.express,
      priceLow: 80000,
      priceHigh: 120000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.scooterOrCar,
      slaMinutes: 120,
      recommended: false,
    ),
  ];
}

class _CountingFakeRepository implements TierRepository {
  const _CountingFakeRepository({required this.onFetch});

  final List<Tier> Function() onFetch;

  @override
  Future<List<Tier>> fetchTiers() async => onFetch();
}
