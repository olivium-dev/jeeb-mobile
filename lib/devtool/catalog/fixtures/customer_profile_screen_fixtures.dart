// Shared dev-only fixtures for `CustomerProfileScreen`.

import 'dart:async';

import 'package:jeeb_mobile/features/customer_profile/data/dev_customer_profile_fixtures.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/rate_app/domain/app_review_launcher.dart';

// ── The repositories. ────────────────────────────────────────────────────────

/// Returns [data] unchanged, so `CustomerProfileCubit.load()` resolves to the
/// same read model the screen was seeded with.
/// The refresh is therefore a same-data no-op: one `loaded` emission, no
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
/// `load()` emits the loading status and only leaves it when the future
class CustomerProfileScreenPendingRepository
    implements CustomerProfileRepository {
  const CustomerProfileScreenPendingRepository();

  @override
  Future<CustomerProfileViewData> fetchProfile() =>
      Completer<CustomerProfileViewData>().future;
}

/// A getMe that fails with a typed [CustomerProfileFailure].
/// The cubit catches it, keeps the seeded header visible and records the
/// failure on `state.error` — which nothing in the screen reads. See the
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
/// Shape-identical to the shipped [NoopAppReviewLauncher], but passed
/// EXPLICITLY by both dev surfaces so neither can fall through to
class CustomerProfileScreenInertReviewLauncher implements AppReviewLauncher {
  const CustomerProfileScreenInertReviewLauncher();

  @override
  Future<void> requestReview() async {
    // Intentionally inert: a dev tool must never raise the OS store-review
  }
}

// ── The designed people. ─────────────────────────────────────────────────────

/// The read models both dev surfaces render.
/// **Every state has its own account holder.** The screen is a header over a
abstract final class CustomerProfileScreenPreviewFixtures {
  /// The catalog's reference customer — verified, rated, with a photo on file.
  /// Aliased to [DevCustomerProfileFixtures.sample] rather than copied, because
  static const CustomerProfileViewData ratedClient =
      DevCustomerProfileFixtures.sample;

  /// The catalog's second state: already a Jeeber, so the
  /// "Register as a delivery" row is hidden (JM-035 AC2 / design §8.2), and
  static const CustomerProfileViewData jeeber = CustomerProfileViewData(
    name: 'Kamal Hajj',
    email: 'kamal.hajj@jeeb.dev',
    isVerified: false,
    isJeeber: true,
    availableRoles: <String>['client', 'jeeber'],
  );

  /// Every field null — what `shell_screen.dart` actually hands the Profile tab
  /// (`CustomerProfileScreen(data: CustomerProfileViewData())`).
  static const CustomerProfileViewData coldStart = CustomerProfileViewData();

  /// A profile handed in through the route's typed `extra` — the other way this
  /// screen is entered (`/profile/customer`), and the only way it is ever
  static const CustomerProfileViewData routeExtra = CustomerProfileViewData(
    name: 'Nadia Client',
    email: 'nadia.client@jeeb.dev',
    isVerified: true,
  );

  /// The layout ceiling: the longest plausible full name against a long
  /// institutional email, on an account that still shows the register row.
  static const CustomerProfileViewData longestContent = CustomerProfileViewData(
    name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
    email: 'abdulrahman.almuhandis@student-mail.university.edu.lb',
    isVerified: true,
    rating: 4.9,
    ratingCount: 312,
  );
}
