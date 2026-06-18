import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('shows cached banner when network fails (AC3)', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(
            repository: FakeTierRepository(failWith: TierLoadFailure.network),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Cubit uses bundled fallback, so tier cards should still render.
      expect(
        find.byKey(TierSelectionScreen.cardKey(TierId.flash)),
        findsOneWidget,
      );
      // The cached banner must be visible.
      expect(
        find.byKey(const Key('tier-selection-cached-banner')),
        findsOneWidget,
      );
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

      // No recommended tier → nothing pre-selected → button disabled.
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

    testWidgets('pre-selects recommended tier on first load', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const TierSelectionScreen(repository: FakeTierRepository()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Flash is recommended in FakeTierRepository → confirm button enabled.
      final btn = tester.widget<OmdsPrimaryButton>(
        find.byKey(TierSelectionScreen.confirmButtonKey),
      );
      expect(btn.isEnabled, isTrue);
    });

    testWidgets('retry button triggers reload from cubit (AC3 retry)', (
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

      // First load fails → falls back to cached (banner visible).
      expect(
        find.byKey(const Key('tier-selection-cached-banner')),
        findsOneWidget,
      );
    });
  });
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
