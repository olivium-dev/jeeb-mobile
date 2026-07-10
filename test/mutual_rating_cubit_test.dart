// Tests for MutualRatingCubit (JM-034).
//
// Verifies:
//   - submit transitions inputting → submitting → submitted (mandatory
//     terminal; the screen navigates home/dashboard on `submitted`).
//   - stars=0 prevents submit.
//   - submit failure emits error phase.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_state.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

class _FakeRatingRepo implements RatingRepository {
  const _FakeRatingRepo({this.failSubmit = false});

  final bool failSubmit;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    if (failSubmit) throw Exception('network error');
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: RatingRevealState.pendingTheirs,
    );
  }
}

void main() {
  group('MutualRatingCubit — setStars', () {
    test('emits updated stars', () {
      final cubit = MutualRatingCubit(
        repository: const _FakeRatingRepo(),
        deliveryId: 'dlv-1',
        isClient: true,
      );
      cubit.setStars(4);
      expect(cubit.state.stars, 4);
      cubit.close();
    });
  });

  group('MutualRatingCubit — submit', () {
    blocTest<MutualRatingCubit, MutualRatingState>(
      'does nothing when stars=0',
      build: () => MutualRatingCubit(
        repository: const _FakeRatingRepo(),
        deliveryId: 'dlv-1',
        isClient: true,
      ),
      act: (c) => c.submit(),
      expect: () => [],
    );

    blocTest<MutualRatingCubit, MutualRatingState>(
      'emits submitting → submitted on success (mandatory terminal)',
      build: () {
        final c = MutualRatingCubit(
          repository: const _FakeRatingRepo(),
          deliveryId: 'dlv-1',
          isClient: true,
        );
        c.setStars(4);
        return c;
      },
      act: (c) => c.submit(),
      expect: () => [
        predicate<MutualRatingState>(
          (s) => s.phase == MutualRatingPhase.submitting,
          'submitting phase',
        ),
        predicate<MutualRatingState>(
          (s) => s.phase == MutualRatingPhase.submitted,
          'submitted phase',
        ),
      ],
    );

    blocTest<MutualRatingCubit, MutualRatingState>(
      'emits error when submit throws',
      build: () {
        final c = MutualRatingCubit(
          repository: const _FakeRatingRepo(failSubmit: true),
          deliveryId: 'dlv-1',
          isClient: true,
        );
        c.setStars(3);
        return c;
      },
      act: (c) => c.submit(),
      expect: () => [
        predicate<MutualRatingState>((s) => s.phase == MutualRatingPhase.submitting),
        predicate<MutualRatingState>(
          (s) => s.phase == MutualRatingPhase.error,
          'error phase after failed submit',
        ),
      ],
    );
  });

  group('MutualRatingCubit — toggleTag', () {
    test('adds then removes a tag', () {
      final cubit = MutualRatingCubit(
        repository: const _FakeRatingRepo(),
        deliveryId: 'dlv-1',
        isClient: true,
      );
      cubit.toggleTag('Friendly');
      expect(cubit.state.tags, contains('Friendly'));
      cubit.toggleTag('Friendly');
      expect(cubit.state.tags, isNot(contains('Friendly')));
      cubit.close();
    });
  });
}
