// Tests for the double-blind reveal path of MutualRatingCubit
// (feedback-double-blind-reveal, SC-043/SC-093).
//
// Verifies revealMode=true: after submit the cubit polls the server-owned
// reveal status and surfaces the counterpart ONLY when the server reports
// revealed / auto-revealed — never inferred client-side. The default
// (mandatory-terminal) path is covered by mutual_rating_cubit_test.dart.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_state.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

class _ScriptedRepo implements RatingRepository {
  _ScriptedRepo(this._statuses);

  final List<RatingStatus> _statuses;
  int _idx = 0;
  bool submitted = false;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    submitted = true;
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    final status = _statuses[_idx.clamp(0, _statuses.length - 1)];
    if (_idx < _statuses.length - 1) _idx++;
    return status;
  }
}

RatingStatus _status(RatingRevealState state, {CounterpartRating? counter}) =>
    RatingStatus(
      deliveryId: 'd1',
      revealState: state,
      counterpartRating: counter,
    );

void main() {
  test('revealMode submit → awaiting while counterpart pending, hidden',
      () async {
    final repo = _ScriptedRepo([_status(RatingRevealState.pendingTheirs)]);
    final cubit = MutualRatingCubit(
      repository: repo,
      deliveryId: 'd1',
      isClient: true,
      revealMode: true,
      maxPolls: 1,
    )..setStars(5);

    await cubit.submit();

    expect(repo.submitted, isTrue);
    expect(cubit.state.phase, MutualRatingPhase.awaitingOther);
    // Counterpart stays hidden until the server reveals.
    expect(cubit.state.counterpartRating, isNull);
    await cubit.close();
  });

  test('first poll already revealed → reveals counterpart immediately',
      () async {
    final repo = _ScriptedRepo([
      _status(
        RatingRevealState.bothRated,
        counter: const CounterpartRating(stars: 4, comment: 'great'),
      ),
    ]);
    final cubit = MutualRatingCubit(
      repository: repo,
      deliveryId: 'd1',
      isClient: false,
      revealMode: true,
    )..setStars(3);

    await cubit.submit();

    expect(cubit.state.phase, MutualRatingPhase.revealed);
    expect(cubit.state.counterpartRating?.stars, 4);
    await cubit.close();
  });

  test('auto-revealed surfaces autoRevealed phase', () async {
    final repo = _ScriptedRepo([_status(RatingRevealState.autoRevealed)]);
    final cubit = MutualRatingCubit(
      repository: repo,
      deliveryId: 'd1',
      isClient: true,
      revealMode: true,
    )..setStars(5);

    await cubit.submit();

    expect(cubit.state.phase, MutualRatingPhase.autoRevealed);
    await cubit.close();
  });

  test('mandatory path (revealMode=false) does NOT poll, lands submitted',
      () async {
    final repo = _ScriptedRepo([_status(RatingRevealState.bothRated)]);
    final cubit = MutualRatingCubit(
      repository: repo,
      deliveryId: 'd1',
      isClient: true,
    )..setStars(5);

    await cubit.submit();

    expect(cubit.state.phase, MutualRatingPhase.submitted);
    expect(cubit.state.counterpartRating, isNull);
    await cubit.close();
  });
}
