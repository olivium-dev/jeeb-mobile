// TEST-17 / LR-26 — the mutual-rating rungs are findable by identifier and a
// double tap issues exactly ONE submit.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/mutual_rating_screen_fixtures.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_state.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// Never completes, so a second tap lands while the first is still in flight.
class _StalledRepository implements RatingRepository {
  int submits = 0;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) {
    submits++;
    return Future<void>.delayed(const Duration(seconds: 5));
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      RatingStatus(
        deliveryId: deliveryId,
        revealState: RatingRevealState.pendingMine,
      );
}

Future<void> _pump(
  WidgetTester tester,
  MutualRatingCubit cubit,
  Locale locale,
) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapForTest(
      BlocProvider<MutualRatingCubit>.value(
        value: cubit,
        child: const MutualRatingScreen(rateeName: 'Rami'),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('the submitting rung is findable ($locale)', (tester) async {
      final cubit = mutualRatingScreenSubmittingCubit();
      await _pump(tester, cubit, locale);
      expect(
        find.bySemanticsIdentifier('mutual_rating_loading'),
        findsOneWidget,
      );
      await cubit.close();
    });

    testWidgets('the error rung carries an identified retry ($locale)',
        (tester) async {
      final cubit = mutualRatingScreenSubmitFailedNetworkCubit();
      await _pump(tester, cubit, locale);
      expect(
        find.bySemanticsIdentifier('mutual_rating_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('mutual_rating_retry_cta'),
        findsOneWidget,
      );
      await cubit.close();
    });

    testWidgets('a 403 gets an EXIT, not a dead block on a canPop:false '
        'screen ($locale)', (tester) async {
      final cubit = MutualRatingCubit(
        repository: const MutualRatingScreenFailingRepository(
          failure: RatingFailure.forbidden,
        ),
        deliveryId: 'DLV-1',
        isClient: true,
      )..setStars(4);
      await cubit.submit();
      await _pump(tester, cubit, locale);

      expect(
        find.bySemanticsIdentifier('mutual_rating_error'),
        findsOneWidget,
      );
      // `forbidden` is non-retryable: without the exit the rung had NO act.
      expect(
        find.bySemanticsIdentifier('mutual_rating_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('mutual_rating_exit_cta'),
        findsOneWidget,
      );
      await cubit.close();
    });
  }

  test('the in-flight guard means a double submit issues ONE call', () async {
    final repo = _StalledRepository();
    final cubit = MutualRatingCubit(
      repository: repo,
      deliveryId: 'DLV-1',
      isClient: true,
    )..setStars(5);

    unawaited(cubit.submit());
    unawaited(cubit.submit());
    await Future<void>.delayed(Duration.zero);

    expect(repo.submits, 1);
    expect(cubit.state.phase, MutualRatingPhase.submitting);
    await cubit.close();
  });

  test('the error state carries a typed failure, never a sentinel string',
      () async {
    final cubit = MutualRatingCubit(
      repository: const MutualRatingScreenFailingRepository(
        failure: RatingFailure.network,
      ),
      deliveryId: 'DLV-1',
      isClient: true,
    )..setStars(4);

    await cubit.submit();

    expect(cubit.state.phase, MutualRatingPhase.error);
    expect(cubit.state.failure, RatingFailure.network);
    await cubit.close();
  });
}
