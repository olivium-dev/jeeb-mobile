// Shared dev-only fixtures for `CustomerProfileScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_02_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/customer_profile/presentation/customer_profile_screen.dart`.
//
// The catalog owned a private `_CatalogCustomerProfileRepository` and a private
// `_jeeberProfileData`. Both moved here verbatim, renamed to their public
// widget-prefixed names, and the catalog now imports them. Two copies of "the
// Jeeber with no ratings yet" would be free to drift, and on this screen the
// designed state IS the header copy — a name, an email, a rating chip — so a
// drifted duplicate is a differently-designed screen wearing the same label.
//
// Two things came with the extraction:
//
//  * **The two repositories the previews need are declared alongside the
//    catalog's one.** `CustomerProfileCubit` has exactly one collaborator, so
//    "in flight" and "failed" are reachable only through what
//    `fetchProfile()` does: [CustomerProfileScreenPendingRepository] never
//    completes, [CustomerProfileScreenFailingRepository] throws the typed
//    failure. Neither is a shortcut around a seam — they ARE the seam.
//  * **Both surfaces now pass an inert [AppReviewLauncher].** Left null, the
//    screen resolves one from GetIt (`_resolveReviewLauncher`), and the Dev
//    Tool shares the app's real GetIt graph — so the day the integrator
//    registers the `in_app_review`-backed adapter, tapping the Rate-app row in
//    a designer's catalog would raise the real App Store review sheet against
//    the real user's account. [CustomerProfileScreenInertReviewLauncher] closes
//    that seam explicitly rather than relying on the registration staying
//    absent. It renders identically.
//
// Everything here is a LOCAL fake over the screen's own `repository:` /
// `reviewLauncher:` constructor seams, so neither surface ever reaches
// `DioCustomerProfileRepository` / `sl<Dio>()` and no state can issue
// `GET /user-management/users/me`. Network-free by construction, not merely by
// the guard `CatalogNetworkGuard` / `jeebPreviewHost` installs.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/customer_profile/data/dev_customer_profile_fixtures.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/rate_app/domain/app_review_launcher.dart';

// ── The repositories. ────────────────────────────────────────────────────────

/// Returns [data] unchanged, so `CustomerProfileCubit.load()` resolves to the
/// same read model the screen was seeded with.
///
/// The refresh is therefore a same-data no-op: one `loaded` emission, no
/// visible transition, and no `GET /user-management/users/me`. This is the
/// catalog's original `_CatalogCustomerProfileRepository`.
class CustomerProfileScreenStaticRepository
    implements CustomerProfileRepository {
  const CustomerProfileScreenStaticRepository(this.data);

  /// What the live getMe is pretended to have returned.
  final CustomerProfileViewData data;

  @override
  Future<CustomerProfileViewData> fetchProfile() async => data;
}

/// A getMe that never lands, holding [CustomerProfileCubit] on
/// `CustomerProfileStatus.loading` for as long as the surface is open.
///
/// `load()` emits the loading status and only leaves it when the future
/// completes, so this is the only way to inspect the cold-start rendering
/// without a real slow connection. Nothing is scheduled — no timer, no tick —
/// so the surface is genuinely still, not animating.
class CustomerProfileScreenPendingRepository
    implements CustomerProfileRepository {
  const CustomerProfileScreenPendingRepository();

  @override
  Future<CustomerProfileViewData> fetchProfile() =>
      Completer<CustomerProfileViewData>().future;
}

/// A getMe that fails with a typed [CustomerProfileFailure].
///
/// The cubit catches it, keeps the seeded header visible and records the
/// failure on `state.error` — which nothing in the screen reads. See the
/// preview section for what that means on screen.
class CustomerProfileScreenFailingRepository
    implements CustomerProfileRepository {
  const CustomerProfileScreenFailingRepository(this.failure);

  /// The typed failure `_fetch` will catch.
  final CustomerProfileFailure failure;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    throw CustomerProfileRepositoryException(
      failure,
      'dev fixture: ${failure.name} (no request was made)',
    );
  }
}

/// An [AppReviewLauncher] that accepts the request and does nothing.
///
/// Shape-identical to the shipped [NoopAppReviewLauncher], but passed
/// EXPLICITLY by both dev surfaces so neither can fall through to
/// `sl<AppReviewLauncher>()` once the real `in_app_review` adapter is
/// registered. See the file header.
class CustomerProfileScreenInertReviewLauncher implements AppReviewLauncher {
  const CustomerProfileScreenInertReviewLauncher();

  @override
  Future<void> requestReview() async {
    // Intentionally inert: a dev tool must never raise the OS store-review
    // sheet against the signed-in user's account.
  }
}

// ── The designed people. ─────────────────────────────────────────────────────

/// The read models both dev surfaces render.
///
/// **Every state has its own account holder.** The screen is a header over a
/// fixed list of eight navigation rows: the rows are identical in every state,
/// so the name, the email and the rating chip are the ONLY things that tell two
/// cards apart. A shared name would let a preview wired to the wrong fixture
/// pass its render test.
abstract final class CustomerProfileScreenPreviewFixtures {
  /// The catalog's reference customer — verified, rated, with a photo on file.
  ///
  /// Aliased to [DevCustomerProfileFixtures.sample] rather than copied, because
  /// that constant is also what the debug `/profile/customer` capture route
  /// renders (`app_router.dart`). Three surfaces, one Sami Fawaz.
  static const CustomerProfileViewData ratedClient =
      DevCustomerProfileFixtures.sample;

  /// The catalog's second state: already a Jeeber, so the
  /// "Register as a delivery" row is hidden (JM-035 AC2 / design §8.2), and
  /// never rated, so the rating chip renders its cold-start copy.
  static const CustomerProfileViewData jeeber = CustomerProfileViewData(
    name: 'Kamal Hajj',
    email: 'kamal.hajj@jeeb.dev',
    isVerified: false,
    isJeeber: true,
    availableRoles: <String>['client', 'jeeber'],
  );

  /// Every field null — what `shell_screen.dart` actually hands the Profile tab
  /// (`CustomerProfileScreen(data: CustomerProfileViewData())`).
  ///
  /// The empty seed is deliberate on the shell's part: "the profile should look
  /// incomplete rather than show a sample person and be mistaken for real
  /// data". So this is the first frame of the Profile tab for EVERY user, not a
  /// synthetic edge case.
  static const CustomerProfileViewData coldStart = CustomerProfileViewData();

  /// A profile handed in through the route's typed `extra` — the other way this
  /// screen is entered (`/profile/customer`), and the only way it is ever
  /// seeded with a real person before getMe answers.
  ///
  /// Deliberately has NO photo and NO rating: it is the state the failing-read
  /// previews are built on, and it has to be unmistakable for the reference
  /// customer at a glance.
  static const CustomerProfileViewData routeExtra = CustomerProfileViewData(
    name: 'Nadia Client',
    email: 'nadia.client@jeeb.dev',
    isVerified: true,
  );

  /// The layout ceiling: the longest plausible full name against a long
  /// institutional email, on an account that still shows the register row.
  ///
  /// Same person as the `CustomerProfileHeader` long-name preview, so the
  /// widget-level and screen-level ceilings describe one customer. `_NameText`
  /// passes no `maxLines`, so this name wraps and grows the header instead of
  /// ellipsizing — which is what pushes the account rows below the fold.
  static const CustomerProfileViewData longestContent = CustomerProfileViewData(
    name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
    email: 'abdulrahman.almuhandis@student-mail.university.edu.lb',
    isVerified: true,
    rating: 4.9,
    ratingCount: 312,
  );
}
