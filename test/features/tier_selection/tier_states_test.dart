// F13/F19/F20/ES-21 — the tier picker's four rungs, told apart.
//
// A 200 with zero tiers used to reach `loaded` with a blank list and a dead
// Confirm; every DioException (403, 500, 429) was reported as a connectivity
// problem; and a parse bug landed on "check your connection".

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_cubit.dart';
import 'package:jeeb_mobile/features/tier_selection/cubit/tier_selection_state.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/features/tier_selection/presentation/tier_selection_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Throwing implements TierRepository {
  const _Throwing(this.failure);

  final Object failure;

  @override
  Future<List<Tier>> fetchTiers() async => throw failure;
}

class _Empty implements TierRepository {
  const _Empty();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

/// A read that never lands — the first frame of every mount.
class _Stalled implements TierRepository {
  const _Stalled();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// Serves the catalogue, then fails — the warm-failure path.
class _ThenFails implements TierRepository {
  _ThenFails();

  int calls = 0;

  @override
  Future<List<Tier>> fetchTiers() async {
    calls++;
    if (calls == 1) return FakeTierRepository.defaultCatalog;
    throw const ServerFailure(status: 503);
  }
}

/// Fails once, then serves the catalogue — proves the retry really refetches.
class _Flaky implements TierRepository {
  _Flaky();

  int calls = 0;

  @override
  Future<List<Tier>> fetchTiers() async {
    calls++;
    if (calls == 1) throw const ServerFailure(status: 500);
    return FakeTierRepository.defaultCatalog;
  }
}

void main() {
  group('TierSelectionCubit · the four rungs', () {
    test('a 200 with zero tiers is LOADED and EMPTY, not an error', () async {
      final cubit = TierSelectionCubit(repository: const _Empty());

      await cubit.load();

      expect(cubit.state.status, TierSelectionStatus.loaded);
      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.canConfirm, isFalse);
      await cubit.close();
    });

    test('a 500 lands on the error rung carrying a ServerFailure', () async {
      final cubit = TierSelectionCubit(
        repository: const _Throwing(ServerFailure(status: 500)),
      );

      await cubit.load();

      expect(cubit.state.status, TierSelectionStatus.error);
      expect(cubit.state.appFailure, const ServerFailure(status: 500));
      await cubit.close();
    });

    // F19: every DioException used to become `TierLoadFailure.network`.
    test('a 403 is NOT classified as a connectivity failure', () async {
      final cubit = TierSelectionCubit(
        repository: const _Throwing(ForbiddenFailure()),
      );

      await cubit.load();

      expect(cubit.state.appFailure, isA<ForbiddenFailure>());
      expect(cubit.state.appFailure, isNot(isA<NetworkFailure>()));
      await cubit.close();
    });

    // F20: the bare `catch (_) → network` swallowed parser bugs.
    test('a TypeError in the parser is classified, never as network', () async {
      final cubit = TierSelectionCubit(
        repository: _Throwing(TypeError()),
      );

      await cubit.load();

      expect(cubit.state.status, TierSelectionStatus.error);
      expect(cubit.state.appFailure, isA<UnknownFailure>());
      await cubit.close();
    });

    // The legacy exception still classifies, for FakeTierRepository.
    test('a legacy TierLoadException still maps to a kind', () async {
      final cubit = TierSelectionCubit(
        repository: const _Throwing(TierLoadException(TierLoadFailure.network)),
      );

      await cubit.load();

      expect(cubit.state.appFailure, isA<NetworkFailure>());
      expect(cubit.state.failure, TierLoadFailure.network);
      await cubit.close();
    });

    // F20 hygiene: a transient refetch failure must not throw away a valid
    // selection the customer already made.
    test('a refetch failure with rows already held KEEPS the selection',
        () async {
      final cubit = TierSelectionCubit(repository: _ThenFails());
      await cubit.load();
      cubit.selectTier(TierId.express);
      final TierId chosen = cubit.state.selectedTierId!;

      await cubit.load();

      expect(cubit.state.status, TierSelectionStatus.error);
      expect(cubit.state.selectedTierId, chosen);
      await cubit.close();
    });

    test('a COLD failure (no rows held) clears the selection', () async {
      final cubit = TierSelectionCubit(
        repository: const _Throwing(ServerFailure(status: 500)),
      );

      await cubit.load();

      expect(cubit.state.selectedTierId, isNull);
      await cubit.close();
    });
  });

  group('TierSelectionScreen · the rungs on screen', () {
    testWidgets('empty renders `tier_selection_empty` and no Confirm', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(const TierSelectionScreen(repository: _Empty())),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('tier_selection_empty'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('tier_selection_error'), findsNothing);
      expect(find.byKey(TierSelectionScreen.confirmButtonKey), findsNothing);
    });

    testWidgets('the loading rung is identified', (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(const TierSelectionScreen(repository: _Stalled())),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('tier_selection_loading'),
        findsOneWidget,
      );
    });

    testWidgets('tapping retry actually refetches', (WidgetTester tester) async {
      useReduceMotion(tester);
      final flaky = _Flaky();
      await tester.pumpWidget(
        wrapForTest(TierSelectionScreen(repository: flaky)),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('tier_selection_error'),
        findsOneWidget,
      );

      final Finder retry =
          find.bySemanticsIdentifier('tier_selection_retry_cta');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(flaky.calls, 2);
      expect(find.bySemanticsIdentifier('tier_selection_error'), findsNothing);
    });
  });
}
