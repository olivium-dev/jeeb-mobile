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
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/domain/tier.dart';
import '../catalog_models.dart';
import '../fixtures/notification_preferences_screen_fixtures.dart';
import '../fixtures/profile_edit_screen_fixtures.dart';
import '../fixtures/request_summary_screen_fixtures.dart';
import '../fixtures/request_summary_unavailable_screen_fixtures.dart';
import '../fixtures/request_type_screen_fixtures.dart';
import '../fixtures/reviews_list_screen_fixtures.dart';
import '../fixtures/saved_addresses_screen_fixtures.dart';
import '../fixtures/settings_screen_fixtures.dart';

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

/// Unlike the live route (which mounts before load completes), `awaitLoad: true`
/// waits for load to finish first, so the name field shows the loaded value.
Widget _profileEditPreview([UserProfile? profile]) =>
    ProfileEditScreenPreviewHost(
      repository: ProfileEditScreenFakeProfileRepository(
        profile ?? profileEditScreenSavedProfile,
      ),
      child: const ProfileEditScreen(),
    );

class _FakeAccountSessionTerminator implements AccountSessionTerminator {
  const _FakeAccountSessionTerminator();

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

/// Mirrors how [showModalBottomSheet] presents a sheet without a live [Navigator].
Widget _logoutDeleteSheetHost(Widget sheet) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Align(alignment: Alignment.bottomCenter, child: sheet),
    ),
  );
}

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
        (_) => RequestTypeScreen(
          repository: RequestTypeScreenPreviewFixtures.stalled(),
        ),
      ),
      CatalogState(
        // R9 loads with the recommended tier lit (doc-13 P0-4).
        'Loaded — served catalogue',
        (_) => RequestTypeScreen(
          repository: RequestTypeScreenPreviewFixtures.servedCatalogue(),
        ),
      ),
      CatalogState(
        // The five rows the board draws.
        'Loaded — full catalogue',
        (_) => RequestTypeScreen(
          repository: RequestTypeScreenPreviewFixtures.fullCatalogue(),
        ),
      ),
      CatalogState(
        // The customer moving the choice off the seeded recommendation.
        'Selected — Flash',
        (_) => RequestTypeScreen(
          cubit: RequestTypeScreenPreviewFixtures.selectedTierCubit(
            TierId.flash,
          ),
        ),
      ),
      CatalogState(
        'Empty — no tiers',
        (_) => RequestTypeScreen(
          repository: RequestTypeScreenPreviewFixtures.emptyCatalogue(),
        ),
      ),
      CatalogState(
        'Error — Network',
        (_) => RequestTypeScreen(
          repository: RequestTypeScreenPreviewFixtures.failing(
            TierLoadFailure.network,
          ),
        ),
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
          jeeberId: reviewsListScreenJeeberId,
          repository: ReviewsListScreenPendingRepository(),
        ),
      ),
      CatalogState(
        'Populated',
        (_) => const ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: StubReviewsRepository(),
        ),
      ),
      CatalogState(
        'Cold-start — New Jeeber',
        (_) => const ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: ReviewsListScreenColdStartRepository(),
        ),
      ),
      CatalogState(
        'Empty',
        (_) => const ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: EmptyReviewsRepository(),
        ),
      ),
      CatalogState(
        'Error — Network',
        (_) => const ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: ReviewsListScreenFailingRepository(
            ReviewsFailure.network,
          ),
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
  // TODO: live_settings_screen — resolves Dio in a field initializer (no seam point)
];
