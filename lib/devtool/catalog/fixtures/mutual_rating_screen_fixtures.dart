// Shared dev-only fixtures for `MutualRatingScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_09_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/rating/presentation/mutual_rating_screen.dart`.
//
// The catalog owned a private `_FakeRatingRepository` plus an
// `_erroredMutualRatingCubit()` helper that reached its designed state by
// firing an UN-AWAITED `submit()` against a repository bound to reject.
// Copying that into the preview section would have given the two surfaces two
// different notions of "the errored rating", free to drift — and would have
// carried the timing dependency along with it. Both surfaces now import this
// file.
//
// ## Why the states are SEEDED rather than driven
//
// `MutualRatingCubit` takes a `repository:` and nothing else: there is no
// `seed:` seam and no way to construct it already in a chosen phase. Three of
// the six designed states are therefore unreachable through its public API —
// `submitting` only exists while a real future is in flight, and the
// server-owned blind-reveal phases (`awaitingOther`/`polling`/`revealed`/
// `autoRevealed`) are never emitted by this cubit at all, only ever arrived at
// with a state restored from elsewhere.
//
// [MutualRatingScreenSeededCubit] is a DEV-ONLY subclass that emits one fixed
// state at construction. It is not a production seam and nothing above a
// banner may reach it; it exists so a fixture can say "this is the phase"
// instead of scripting an async race and hoping the surface samples it at the
// right moment.
//
// Every repository here is a LOCAL fake — no Dio, no GetIt, no network — so
// both surfaces are network-free by construction rather than merely by the
// `CatalogNetworkGuard` their hosts install. Each is `const`-constructible so a
// caller can keep the whole fixture tree const.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_state.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

/// The delivery every fixture state rates.
///
/// Nothing on screen renders it — `MutualRatingScreen` shows no reference, no
/// counterpart name and no order id — so this is a wire-level detail only. It
/// is shared so the catalog and the canvas describe the same delivery.
const String mutualRatingScreenDeliveryId = 'DEL-4021';

/// The tag keys, in the order `kMutualRatingTags` declares them.
///
/// These are the ON-THE-WIRE gateway taxonomy keys (JEBV4-297), never the
/// display labels — a fixture that seeded `'Friendly'` would render an
/// unselected chip and quietly prove nothing.
const List<String> mutualRatingScreenAllTags = <String>[
  'punctuality',
  'communication',
  'package_condition',
  'courtesy',
  'navigation',
];

/// The longest comment the field accepts is 500 characters; this is a
/// realistic long one.
///
/// Seeded into `MutualRatingState.comment` for the filled state. Note that it
/// does NOT appear on screen — `_CommentField` takes `comment` and never reads
/// it, so a restored or seeded comment renders as an empty field with the hint
/// showing. The fixture keeps the value anyway: the state is only honest if the
/// comment is part of it, and the gap between "the cubit holds this" and "the
/// field shows nothing" is exactly what the preview is for.
const String mutualRatingScreenLongComment =
    'Arrived four minutes early, called from the gate instead of ringing the '
    'bell because the baby was asleep, and carried both boxes up to the third '
    'floor without being asked. The cold bag was still cold. Easily the '
    'smoothest handover I have had on this app.';

/// Canned [RatingRepository] — `submitRating` succeeds immediately.
///
/// The success path is what the catalog's two "Rate" states use: tapping
/// submit resolves, the cubit reaches `MutualRatingPhase.submitted`, and the
/// screen's listener navigates. Only a host that supplies a `Router` can
/// survive that tap — see the preview section's `_MutualRatingScreenHost`.
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
///
/// [failure] changes nothing the user sees — the cubit collapses every failure
/// onto one `MutualRatingPhase.error` with a single localized message — so it
/// exists only so a fixture can say WHICH failure it is describing. The default
/// is [RatingFailure.network]; [RatingFailure.unknown] is the 403 "you are not
/// a party to this delivery", which is the one that never recovers.
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
///
/// `submit()` emits `submitting` and only leaves it when the future completes,
/// so this is the only way to inspect the in-flight spinner without a real slow
/// connection.
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
///
/// DEV-ONLY. The emit happens in the constructor, before any surface has
/// subscribed, so the screen's `BlocConsumer.listenWhen` never sees it as a
/// phase CHANGE — which is what keeps a seeded `submitted` from firing
/// `context.go('/')` the instant the widget mounts. (No fixture seeds
/// `submitted` for that reason; it is a transition, not a picture.)
///
/// Everything else about the cubit is real: `setStars`, `setComment`,
/// `toggleTag` and `submit` behave exactly as production, against whichever
/// local fake [repository] the state was built with.
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
///
/// Zero stars means `rating_submit_cta` is DISABLED, which is the only thing
/// standing between the user and an empty rating.
MutualRatingCubit mutualRatingScreenFreshCubit({bool isClient = true}) =>
    MutualRatingCubit(
      repository: const MutualRatingScreenFakeRepository(),
      deliveryId: mutualRatingScreenDeliveryId,
      isClient: isClient,
    );

/// Everything filled in: five stars, all five quick tags selected, and a long
/// comment in cubit state.
///
/// The tallest input the screen can hold, and the state that decides whether
/// the tag [Wrap] survives AR and 200% text.
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
///
/// Paired with [MutualRatingScreenPendingRepository] so the phase is stable:
/// tapping retry or resubmitting cannot move it on.
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
///
/// `errorMessage` mirrors what the cubit sets (`'ratingError'`); the screen
/// ignores it and renders the localized `mutualRatingError` copy instead, so
/// the value is documentation rather than input. Backed by a repository that
/// keeps rejecting, so the retry button behaves the way it does against a
/// permanent failure (403 "not a party to this delivery"): straight back here.
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
///
/// `MutualRatingCubit` never emits `awaitingOther` — the JM-034 path is
/// fire-and-forget — but `MutualRatingState` still models it and
/// `_buildBody` still has a branch for it, documented as "fall back to the
/// input view so a stale state never strands the user without a submit
/// affordance". This fixture is that branch, made lookable-at: a rating that
/// was already submitted, presented as a blank form.
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
