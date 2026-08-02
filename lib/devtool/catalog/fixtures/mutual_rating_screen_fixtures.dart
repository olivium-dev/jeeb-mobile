// Shared dev-only fixtures for `MutualRatingScreen`.

import 'dart:async';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_state.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

/// The delivery every fixture state rates.
/// Nothing on screen renders it — `MutualRatingScreen` shows no reference, no
const String mutualRatingScreenDeliveryId = 'DEL-4021';

/// The tag keys, in the order `kMutualRatingTags` declares them.
/// These are the ON-THE-WIRE gateway taxonomy keys (JEBV4-297), never the
const List<String> mutualRatingScreenAllTags = <String>[
  'punctuality',
  'communication',
  'package_condition',
  'courtesy',
  'navigation',
];

/// The longest comment the field accepts is 500 characters; this is a
/// realistic long one.
const String mutualRatingScreenLongComment =
    'Arrived four minutes early, called from the gate instead of ringing the '
    'bell because the baby was asleep, and carried both boxes up to the third '
    'floor without being asked. The cold bag was still cold. Easily the '
    'smoothest handover I have had on this app.';

/// Canned [RatingRepository] — `submitRating` succeeds immediately.
/// The success path is what the catalog's two "Rate" states use: tapping
/// submit resolves, the cubit reaches `MutualRatingPhase.submitted`, and the
class MutualRatingScreenFakeRepository implements RatingRepository {
  const MutualRatingScreenFakeRepository();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      RatingStatus(
        deliveryId: deliveryId,
        revealState: RatingRevealState.pendingMine,
      );
}

/// A submit that throws the way the data layer is contracted to fail: a typed
/// [RatingRepositoryException], never a raw `DioException`.
/// [failure] changes nothing the user sees — the cubit collapses every failure
class MutualRatingScreenFailingRepository implements RatingRepository {
  const MutualRatingScreenFailingRepository({
    this.failure = RatingFailure.network,
  });

  final RatingFailure failure;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    throw RatingRepositoryException(failure);
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    throw RatingRepositoryException(failure);
  }
}

/// A submit that never lands, holding the screen on
/// `MutualRatingPhase.submitting` for as long as the surface is open.
/// `submit()` emits `submitting` and only leaves it when the future completes,
class MutualRatingScreenPendingRepository implements RatingRepository {
  const MutualRatingScreenPendingRepository();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) =>
      Completer<void>().future;

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) =>
      Completer<RatingStatus>().future;
}

/// A [MutualRatingCubit] that starts in [seed] instead of the default
/// `inputting` state.
/// DEV-ONLY. The emit happens in the constructor, before any surface has
class MutualRatingScreenSeededCubit extends MutualRatingCubit {
  MutualRatingScreenSeededCubit({
    required MutualRatingState seed,
    required super.repository,
    required super.deliveryId,
    required super.isClient,
  }) {
    emit(seed);
  }
}

/// The state every user opens the mandatory terminal in: nothing rated yet.
/// Zero stars means `rating_submit_cta` is DISABLED, which is the only thing
MutualRatingCubit mutualRatingScreenFreshCubit({bool isClient = true}) =>
    MutualRatingCubit(
      repository: const MutualRatingScreenFakeRepository(),
      deliveryId: mutualRatingScreenDeliveryId,
      isClient: isClient,
    );

/// Everything filled in: five stars, all five quick tags selected, and a long
/// comment in cubit state.
MutualRatingCubit mutualRatingScreenFilledCubit() =>
    MutualRatingScreenSeededCubit(
      repository: const MutualRatingScreenFakeRepository(),
      deliveryId: mutualRatingScreenDeliveryId,
      isClient: true,
      seed: const MutualRatingState(
        stars: 5,
        comment: mutualRatingScreenLongComment,
        tags: mutualRatingScreenAllTags,
      ),
    );

/// `POST /v1/ratings/jeeb/submit` in flight — the whole body is replaced by a
/// centred spinner.
MutualRatingCubit mutualRatingScreenSubmittingCubit() =>
    MutualRatingScreenSeededCubit(
      repository: const MutualRatingScreenPendingRepository(),
      deliveryId: mutualRatingScreenDeliveryId,
      isClient: true,
      seed: const MutualRatingState(
        phase: MutualRatingPhase.submitting,
        stars: 5,
      ),
    );

/// The submit was rejected.
/// `errorMessage` mirrors what the cubit sets (`'ratingError'`); the screen
MutualRatingCubit mutualRatingScreenErrorCubit() =>
    MutualRatingScreenSeededCubit(
      repository: const MutualRatingScreenFailingRepository(
        failure: RatingFailure.unknown,
      ),
      deliveryId: mutualRatingScreenDeliveryId,
      isClient: true,
      seed: const MutualRatingState(
        phase: MutualRatingPhase.error,
        stars: 4,
        errorMessage: 'ratingError',
      ),
    );

/// A server-owned blind-reveal phase restored onto the mandatory terminal.
/// `MutualRatingCubit` never emits `awaitingOther` — the JM-034 path is
MutualRatingCubit mutualRatingScreenAwaitingOtherCubit() =>
    MutualRatingScreenSeededCubit(
      repository: const MutualRatingScreenFakeRepository(),
      deliveryId: mutualRatingScreenDeliveryId,
      isClient: true,
      seed: const MutualRatingState(
        phase: MutualRatingPhase.awaitingOther,
        stars: 5,
        tags: <String>['courtesy'],
      ),
    );
