// Shared dev-only fixtures for `RatingScreen` — the legacy `/orders/:id/feedback`
// terminal (JM-034 AC4).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_09_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/rating/presentation/rating_screen.dart`.
//
// The catalog owned a private `_FakeRatingRepository` and two inline ratee
// names. Both moved here unchanged, so the two surfaces cannot drift: the
// catalog is what a designer signs off against, and a preview that quietly
// renamed "Rami Chidiac" would be reviewing a different screen from the one
// that was approved.
//
// The sibling `MutualRatingScreen` — the canonical terminal this legacy
// `/feedback` variant was reconciled against (JM-034 AC4) — has a fixture file
// of its own (`mutual_rating_screen_fixtures.dart`), even though both screens
// stand on the same `RatingRepository` contract. They are kept apart because
// they seed through different seams: `RatingScreen` takes a `repository:`
// constructor argument and drives its own `State`, while `MutualRatingScreen`
// reads a `MutualRatingCubit` from context. Neither screen's designed states
// should be able to move when the other's are edited.
//
// Everything here is a LOCAL fake: `RatingScreen` takes a `repository:` seam,
// so neither surface reaches its `sl<RatingRepository>()` branch and neither can
// touch the live gateway. Network-free by construction, not merely by the
// `CatalogNetworkGuard` both hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

/// Canned [RatingRepository]: a submit that always resolves, or — with
/// [throwOnSubmit] — one that always fails the way the live repository fails,
/// with a TYPED [RatingRepositoryException] rather than a bare `Exception`.
///
/// `const`-constructible so the catalog can keep building
/// `const RatingScreen(repository: ...)`.
class RatingScreenFakeRepository implements RatingRepository {
  const RatingScreenFakeRepository({this.throwOnSubmit = false});

  /// When true, `POST /v1/ratings/jeeb/submit` is simulated as unreachable.
  final bool throwOnSubmit;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    if (throwOnSubmit) {
      throw const RatingRepositoryException(RatingFailure.network);
    }
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: RatingRevealState.pendingMine,
    );
  }
}

/// A submit that never lands, holding `RatingScreen` on its in-flight state for
/// as long as the surface is open.
///
/// `_RatingScreenState._submitting` is set to true immediately and only ever
/// read again by the `context.go('/')` that follows the awaited call, so an
/// unsettleable [Completer] is the only way to inspect the CTA spinner without
/// a real slow connection. It holds no timer and no subscription — it simply
/// never settles, which is also what keeps the state from navigating away
/// mid-review.
///
/// `fetchRatingStatus` is unreachable from this screen (only `MutualRatingCubit`
/// calls it) and stalls too rather than throwing, so a future caller that starts
/// polling here cannot get a false green from this fixture.
class RatingScreenStalledRepository implements RatingRepository {
  const RatingScreenStalledRepository();

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

/// The delivery both dev surfaces rate. Only ever echoed into the route path —
/// this screen never renders it.
const String ratingScreenDeliveryId = 'DEL-3390';

/// The jeeber a client is rating (catalog: "Feedback — Client Rates Jeeber").
const String ratingScreenJeeberRatee = 'Rami Chidiac';

/// The client a jeeber is rating (catalog: "Feedback — Jeeber Rates Client").
const String ratingScreenClientRatee = 'Layla Haddad';

/// The layout ceiling: a full Levantine name as `GET /users/me` returns it,
/// unabbreviated.
///
/// `_FeedbackRateName` sets no `maxLines` and no `overflow`, so this is the
/// fixture that shows how the centred "Rate {name}" line degrades — and, at
/// 200% text, whether it still fits above the star row.
const String ratingScreenLongRatee = 'Abd Al-Rahman Al-Muhandis Al-Trabulsi';

/// Ratee for the "four stars picked, not yet submitted" state.
///
/// Every driven state carries a name of its own for the same reason the wallet
/// fixtures each carry a distinct row: these previews differ only in private
/// `State` fields the screen exposes no seam for, so without a distinct string
/// a render test could not tell one from another and would pass with all three
/// wired to the same fixture.
const String ratingScreenRatedRatee = 'Karim Nassar';

/// Ratee for the in-flight submit state.
const String ratingScreenSubmittingRatee = 'Nour Ghanem';

/// Ratee for the failed submit state.
const String ratingScreenFailedRatee = 'Hadi Mansour';
