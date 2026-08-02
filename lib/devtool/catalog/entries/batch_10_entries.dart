import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';
import '../../../features/request_summary/domain/request_submission_service.dart';
import '../../../features/request_summary/presentation/request_summary_screen.dart';
import '../../../features/request_summary/presentation/request_summary_unavailable_screen.dart';
import '../../../features/request_type/presentation/request_type_screen.dart';
import '../../../features/reviews/data/empty_reviews_repository.dart';
import '../../../features/reviews/data/stub_reviews_repository.dart';
import '../../../features/reviews/domain/reviews_repository.dart';
import '../../../features/reviews/presentation/reviews_list_screen.dart';
import '../../../features/settings/application/settings_cubit.dart';
import '../../../features/settings/domain/account_session_terminator.dart';
import '../../../features/settings/domain/user_profile.dart';
import '../../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../../features/settings/presentation/screens/settings_screen.dart';
import '../../../features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../../../features/settlement/domain/settlement_repository.dart';
import '../../../features/settlement/presentation/settlement_detail_screen.dart';
import '../../../features/settlement/presentation/settlement_screen.dart';
import '../../../features/tier_selection/cubit/tier_selection_cubit.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/domain/tier.dart';
import '../catalog_models.dart';
import '../fixtures/notification_preferences_screen_fixtures.dart';
import '../fixtures/profile_edit_screen_fixtures.dart';
import '../fixtures/request_summary_screen_fixtures.dart';
import '../fixtures/request_summary_unavailable_screen_fixtures.dart';
import '../fixtures/saved_addresses_screen_fixtures.dart';
import '../fixtures/settlement_detail_screen_fixtures.dart';
import '../fixtures/settlement_screen_fixtures.dart';
import '../fixtures/settings_screen_fixtures.dart';
import '../tier_catalog_fixture.dart';

// Batch 10 — request_summary, request_type, reviews, search, settings,
// settlement. `live_settings_screen.dart` is SKIPPED (see bottom of file): it
// resolves `sl<Dio>()` inside a field initializer with no constructor seam, so
// previewing it locally would either hit the live gateway or require reaching
// into GetIt registration, out of scope for an additive catalog batch.

// ─────────────────────────────────────────────────────────────────────────────
// request_summary — the accepted-request review + submit card
// (RequestSummaryScreen) and its cold-deep-link fallback
// (RequestSummaryUnavailableScreen). The cubit has no DI default (the caller
// always supplies a [RequestDraft] via `setDraft`), so every state seeds the
// draft directly; a real submit success navigates away (`context.go('/')`),
// which has no "designed" rendered state of its own — only Loaded / Submitting
// / Error are previewed.
//
// The fake service, the sample draft and the seeding host used to live here.
// They now live in `../fixtures/request_summary_screen_fixtures.dart`, which
// the JEEB PREVIEWS section of `request_summary_screen.dart` reads too — so
// these three designed states and the engineer-facing canvas cannot drift
// apart. The states below are unchanged: same labels, same draft, same three
// service behaviours. `standInRouter` is left at its default `false` because
// the catalog runs inside the app, where a real router is already above the
// screen.
// ─────────────────────────────────────────────────────────────────────────────

Widget _requestSummaryScreen(
  RequestSubmissionService service, {
  bool drive = false,
}) {
  return RequestSummaryScreenPreviewHost(
    screen: const RequestSummaryScreen(),
    service: service,
    draft: RequestSummaryScreenDrafts.full,
    drive: drive,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// request_type — tier selection (RequestTypeScreen). Both `repository` and
// `cubit` are existing constructor test seams (§5.4) — no seam addition
// needed. The loaded previews use the delivery-service's current three-tier
// contract rather than the wider legacy fake catalog.
// ─────────────────────────────────────────────────────────────────────────────

/// Never resolves — keeps the screen on its centered spinner for a stable
/// "Loading" catalog state.
class _PendingTierRepository implements TierRepository {
  const _PendingTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// Drives the cubit to a loaded state with [select] chosen, via the same
/// "load, then act once it resolves" trick as the `otp_handover` escalate
/// preview (batch 08) — `selectTier` is a no-op until `load()` has landed.
TierSelectionCubit _selectedTierCubit(TierId select) {
  final cubit = TierSelectionCubit(repository: const DevtoolTierRepository());
  unawaited(cubit.load().then((_) => cubit.selectTier(select)));
  return cubit;
}

// ─────────────────────────────────────────────────────────────────────────────
// reviews — the all-reviews list (ReviewsListScreen, JM-068). `jeeberId` +
// `repository` are existing constructor test seams (§5.4).
// ─────────────────────────────────────────────────────────────────────────────

const String _reviewsJeeberId = 'jeeber-042';

/// Never resolves — keeps the screen on the first-load skeletons (D73).
class _PendingReviewsRepository implements ReviewsRepository {
  const _PendingReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) {
    return Completer<ReviewsPage>().future;
  }

  @override
  Future<void> reportReview(String reviewId) => Completer<void>().future;
}

class _FailingReviewsRepository implements ReviewsRepository {
  const _FailingReviewsRepository(this.failure);

  final ReviewsFailure failure;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ReviewsRepositoryException(failure);
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// D59 cold-start posture: < 5 ratings hides the aggregate score behind the
/// "New" badge while the individual row still renders.
class _ColdStartReviewsRepository implements ReviewsRepository {
  const _ColdStartReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ReviewsPage(
      reviews: [
        ReviewItem(
          id: 'review-101',
          reviewerFirstName: 'Nour',
          score: 5,
          timestamp: '2026-06-30T10:00:00.000Z',
          body: 'Great first delivery!',
        ),
      ],
      page: 1,
      totalPages: 1,
      coldStart: true,
      reviewCount: 1,
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

// ─────────────────────────────────────────────────────────────────────────────
// settings — SettingsScreen. `cubit` is an existing constructor test seam, and
// the screen's `_LanguageSection` reads `context.watch<LocaleCubit>()`
// unconditionally, so every state ALSO needs a real [LocaleCubit] ancestor over
// a `SharedPreferences`.
//
// Both halves — the seeded cubits and that seating — moved to
// `../fixtures/settings_screen_fixtures.dart`, shared verbatim with the preview
// section at the bottom of `settings_screen.dart`, so the designer's browser
// and the engineer's canvas cannot show two different "designed states". The
// prefs there are in-memory, so the async `SharedPreferences.getInstance()`
// seam this entry used to carry — and the blank first frame it produced — is
// gone; the deletion-pending state is seeded rather than driven through
// `requestAccountDeletion()`, so it no longer pops a four-second SnackBar over
// the surface. Same pixels, minus the transients.
//
// The Active-Role toggle only reads `RoleCubit` from a user GESTURE
// (`_onChanged`), never from `build`, so no `RoleCubit` ancestor is needed to
// render these statically.
// ─────────────────────────────────────────────────────────────────────────────

// The profile-edit fakes and the sample profiles live in
// `../fixtures/profile_edit_screen_fixtures.dart` so that entry and the preview
// section at the bottom of `profile_edit_screen.dart` mock the screen from ONE
// set of fixtures — including WHEN the host mounts the screen relative to
// `load()`, which is the only thing that decides what the name field contains.

/// Async-seam host for [ProfileEditScreen] (no `cubit` ctor param of its own —
/// it reads `SettingsCubit` from context), shared verbatim with the preview
/// section at the bottom of `profile_edit_screen.dart`:
/// [ProfileEditScreenPreviewHost] with `awaitLoad: true`.
///
/// `awaitLoad: true` waits for the fake profile load to complete BEFORE first
/// build, so the name field's `initState`-seeded [TextEditingController]
/// starts from the loaded name rather than the empty default. Note that this
/// is NOT what `app_router.dart` does — the live route builds
/// `SettingsCubit(...)..load()` and mounts the screen in the same frame, so a
/// real user's name field starts empty. The preview section carries that state
/// (`Loads after mount · the name field stays blank`); this entry keeps
/// showing the designed one.
Widget _profileEditPreview([UserProfile? profile]) =>
    ProfileEditScreenPreviewHost(
      repository: ProfileEditScreenFakeProfileRepository(
        profile ?? profileEditScreenSavedProfile,
      ),
      child: const ProfileEditScreen(),
    );

// The two notification-prefs fakes used to live here as private classes. They
// now live in `../fixtures/notification_preferences_screen_fixtures.dart`
// (`NotificationPreferencesScreenFakeRepository` /
// `NotificationPreferencesScreenPendingRepository`) so that this entry and the
// preview section at the bottom of
// `lib/features/settings/presentation/screens/notification_preferences_screen.dart`
// mock the screen from ONE set of designed states instead of two copies free
// to drift.

class _FakeAccountSessionTerminator implements AccountSessionTerminator {
  const _FakeAccountSessionTerminator();

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

/// Bottom-sheet preview host (mirrors `_sheetHost` in batch 02):
/// [LogoutDeleteConfirmSheet] is a sheet, not a route — it renders a bare
/// column, not a `Scaffold`. Pinning it to the bottom of a plain `Scaffold`
/// mirrors how `showModalBottomSheet` actually presents it without depending
/// on a live `Navigator`/modal route.
Widget _logoutDeleteSheetHost(Widget sheet) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Align(alignment: Alignment.bottomCenter, child: sheet),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// settlement — the weekly statements list (SettlementScreen, `repository` is
// an existing constructor test seam) and the per-statement breakdown
// (SettlementDetailScreen, a plain `statement` value — no repository at all).
// ─────────────────────────────────────────────────────────────────────────────

// The two fakes this section declared privately
// (`_FakeSettlementRepository`, `_PendingSettlementRepository`) moved to
// `../fixtures/settlement_screen_fixtures.dart` as
// `SettlementScreenFakeRepository` / `SettlementScreenPendingRepository`
// (behaviour unchanged) so the catalog and the JEEB PREVIEWS section at the
// bottom of `settlement_screen.dart` drive the four states below through the
// SAME fake. That file adds three knobs the catalog does not use
// (`fetchThrowsUnmapped`, `downloadFailure`, `downloadPending`), which is the
// same arrangement as `transaction_detail_screen_fixtures.dart`.

// The two designed statements moved to
// `../fixtures/settlement_detail_screen_fixtures.dart` (values unchanged) so
// the catalog and the `SettlementDetailScreen` preview section cannot drift.
// `settlementDetailScreenSampleWeeks` is the list this batch used to build
// inline as `_sampleStatements()`.

// ─────────────────────────────────────────────────────────────────────────────
// Catalog entries
// ─────────────────────────────────────────────────────────────────────────────

List<CatalogEntry> get batch10Entries => <CatalogEntry>[
  CatalogEntry(
    feature: 'request_summary',
    screen: 'RequestSummaryScreen',
    states: [
      CatalogState(
        'Loaded',
        (_) => _requestSummaryScreen(
          const RequestSummaryScreenFakeSubmissionService(),
        ),
      ),
      CatalogState(
        'Submitting',
        (_) => _requestSummaryScreen(
          const RequestSummaryScreenFakeSubmissionService(pending: true),
          drive: true,
        ),
      ),
      CatalogState(
        'Error — Network',
        (_) => _requestSummaryScreen(
          const RequestSummaryScreenFakeSubmissionService(
            failure: RequestSubmissionFailure.network,
          ),
          drive: true,
        ),
      ),
    ],
  ),
  // The label and the framing come from
  // `../fixtures/request_summary_unavailable_screen_fixtures.dart`, which the
  // JEEB PREVIEWS section at the bottom of
  // `request_summary_unavailable_screen.dart` also reads — so this state and the
  // canvas cannot drift apart. `window: null` + `parentOnStack: null` is the
  // host's pass-through form: the screen renders bare on the real device under
  // the catalog's own route, exactly as this entry did before the extraction.
  CatalogEntry(
    feature: 'request_summary',
    screen: 'RequestSummaryUnavailableScreen',
    states: [
      CatalogState(
        requestSummaryUnavailableScreenCatalogStateLabel,
        (_) => const RequestSummaryUnavailableScreenPreviewHost(
          screen: RequestSummaryUnavailableScreen(),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'request_type',
    screen: 'RequestTypeScreen',
    states: [
      CatalogState(
        'Loading',
        (_) => const RequestTypeScreen(repository: _PendingTierRepository()),
      ),
      CatalogState(
        'Loaded — no selection',
        (_) => const RequestTypeScreen(repository: DevtoolTierRepository()),
      ),
      CatalogState(
        'Selected — Standard',
        (_) => RequestTypeScreen(cubit: _selectedTierCubit(TierId.standard)),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'reviews',
    screen: 'ReviewsListScreen',
    states: [
      CatalogState(
        'Loading',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: _PendingReviewsRepository(),
        ),
      ),
      CatalogState(
        'Populated',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: StubReviewsRepository(),
        ),
      ),
      CatalogState(
        'Cold-start — New Jeeber',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: _ColdStartReviewsRepository(),
        ),
      ),
      CatalogState(
        'Empty',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: EmptyReviewsRepository(),
        ),
      ),
      CatalogState(
        'Error — Network',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: _FailingReviewsRepository(ReviewsFailure.network),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'SettingsScreen',
    states: [
      CatalogState(
        'Loaded — Profile',
        (_) => SettingsScreenPreviewHost(
          create: SettingsScreenPreviewFixtures.loadedProfile,
          builder: (SettingsCubit cubit) => SettingsScreen(cubit: cubit),
        ),
      ),
      CatalogState(
        'Loaded — Deletion Pending',
        (_) => SettingsScreenPreviewHost(
          create: SettingsScreenPreviewFixtures.deletionPending,
          builder: (SettingsCubit cubit) => SettingsScreen(cubit: cubit),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'ProfileEditScreen',
    states: [
      CatalogState('Loaded', (_) => _profileEditPreview()),
      CatalogState(
        'Empty — No Name Yet',
        (_) => _profileEditPreview(profileEditScreenNoNameProfile),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'NotificationPreferencesScreen',
    states: [
      CatalogState(
        'Loading',
        (_) => const NotificationPreferencesScreen(
          repository: NotificationPreferencesScreenPendingRepository(),
        ),
      ),
      CatalogState(
        'Loaded',
        (_) => const NotificationPreferencesScreen(
          repository: NotificationPreferencesScreenFakeRepository(
            prefs: notificationPreferencesScreenDefaultPrefs,
          ),
        ),
      ),
      CatalogState(
        'Error',
        (_) => const NotificationPreferencesScreen(
          repository: NotificationPreferencesScreenFakeRepository(
            fetchFailure: NotificationPrefsFailure.network,
          ),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'SavedAddressesScreen',
    // One state, because the screen has one — see
    // `../fixtures/saved_addresses_screen_fixtures.dart`, shared verbatim with
    // the JEEB PREVIEWS section at the bottom of the screen's own file so the
    // designer's on-device state and the engineer's canvas state stay the same
    // state.
    states: [
      CatalogState(
        SavedAddressesScreenFixtures.placeholderLabel,
        (_) => SavedAddressesScreenFixtures.placeholder(),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'LogoutDeleteConfirmSheet',
    states: [
      CatalogState(
        'Sign Out',
        (_) => _logoutDeleteSheetHost(
          const LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.logout,
            terminator: _FakeAccountSessionTerminator(),
          ),
        ),
      ),
      CatalogState(
        'Delete Account',
        (_) => _logoutDeleteSheetHost(
          const LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.delete,
            terminator: _FakeAccountSessionTerminator(),
          ),
        ),
      ),
      CatalogState(
        'Both',
        (_) => _logoutDeleteSheetHost(
          const LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.both,
            terminator: _FakeAccountSessionTerminator(),
          ),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settlement',
    screen: 'SettlementScreen',
    states: [
      CatalogState(
        'Loading',
        (_) =>
            const SettlementScreen(repository: SettlementScreenPendingRepository()),
      ),
      CatalogState(
        'Ready — Mixed',
        (_) => const SettlementScreen(
          repository: SettlementScreenFakeRepository(
            statements: settlementDetailScreenSampleWeeks,
          ),
        ),
      ),
      CatalogState(
        'Empty',
        (_) => const SettlementScreen(
          repository: SettlementScreenFakeRepository(),
        ),
      ),
      CatalogState(
        'Error',
        (_) => const SettlementScreen(
          repository: SettlementScreenFakeRepository(
            fetchFailure: SettlementFailure.network,
          ),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settlement',
    screen: 'SettlementDetailScreen',
    states: [
      CatalogState(
        'Paid',
        (_) => const SettlementDetailScreen(
          statement: settlementDetailScreenPaidWeek,
        ),
      ),
      CatalogState(
        'Pending',
        (_) => const SettlementDetailScreen(
          statement: settlementDetailScreenPendingWeek,
        ),
      ),
    ],
  ),

  // live_settings_screen.dart — SKIPPED. `LiveSettingsScreen` resolves
  // `sl<Dio>().get('/v1/users/me')` inside a `late Future` FIELD
  // INITIALIZER (before `build`, before any constructor seam could
  // intervene) and has no constructor param of its own — the generic,
  // seamed `SettingsScreen` it wraps is already cataloged above. Adding a
  // seam here would mean threading a fake `Dio`/response through a
  // field-initializer future, which is a bigger surgery than "minimal
  // additive" for a live-gateway host with no unique designed state beyond
  // what `SettingsScreen` already renders.
];
