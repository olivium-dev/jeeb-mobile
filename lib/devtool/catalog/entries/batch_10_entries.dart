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
import '../../../features/settings/presentation/screens/live_settings_screen.dart';
import '../../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../../features/settings/presentation/screens/settings_screen.dart';
import '../../../features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/domain/tier.dart';
import '../../../core/network/app_failure.dart';
import '../../../features/settings/domain/notification_preferences.dart';
import '../../../features/settings/domain/profile_repository.dart';
import '../catalog_models.dart';
import '../fixtures/notification_preferences_screen_fixtures.dart';
import '../fixtures/profile_edit_screen_fixtures.dart';
import '../fixtures/request_summary_screen_fixtures.dart';
import '../fixtures/request_summary_unavailable_screen_fixtures.dart';
import '../fixtures/request_type_screen_fixtures.dart';
import '../fixtures/reviews_list_screen_fixtures.dart';
import '../fixtures/middle_failure_scenarios.dart';
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
/// The settings rungs a canned profile cannot reach.
Widget _settingsOverProfileRepository(
  ProfileRepository repository, {
  SettingsNotificationPrefsStore? notificationStore,
  Future<void> Function(SettingsCubit)? afterLoad,
}) => SettingsScreenPreviewHost(
  create: () {
    final SettingsCubit cubit = SettingsCubit(
      profileRepository: repository,
      accountService: const SettingsScreenFakeAccountService(),
      notificationStore: notificationStore,
    );
    unawaited(() async {
      await cubit.load();
      if (!cubit.isClosed) await afterLoad?.call(cubit);
    }());
    return cubit;
  },
  builder: (SettingsCubit cubit) => SettingsScreen(cubit: cubit),
);

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
      CatalogState(
        'Moderation — needs acknowledgment',
        (_) => _requestSummaryScreen(
          const RequestSummaryScreenFakeSubmissionService.moderation(),
          drive: true,
        ),
      ),
      CatalogState(
        'Moderation — blocked (exit, no retry)',
        (_) => _requestSummaryScreen(
          const RequestSummaryScreenFakeSubmissionService.moderation(
            blocked: true,
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
      CatalogState(
        'Error — Unavailable (503)',
        (_) => RequestTypeScreen(
          repository: RequestTypeScreenPreviewFixtures.unavailable(),
        ),
      ),
      CatalogState(
        'Error — Forbidden (403)',
        (_) => RequestTypeScreen(
          repository: RequestTypeScreenPreviewFixtures.forbidden(),
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
      CatalogState(
        'Refresh failed over rows (LR-07)',
        (_) => catalogReviewFailure(ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: ReviewsListScreenRefreshFailingRepository(
            ReviewsListScreenPages.longestContent,
          ),
        ), CatalogReviewAction.refresh),
      ),
      CatalogState(
        'Load-more failed (TEST-16)',
        (_) => catalogReviewFailure(const ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: ReviewsListScreenLoadMoreFailingRepository(
            ReviewsListScreenPages.longestContent,
          ),
        ), CatalogReviewAction.loadMore),
      ),
      CatalogState(
        'Report conflict — already rated (AE-25)',
        (_) => catalogReviewFailure(const ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: ReviewsListScreenReportConflictRepository(
            ReviewsListScreenPages.longestContent,
          ),
        ), CatalogReviewAction.report),
      ),
      CatalogState(
        'Error — unauthorized (sign-in exit)',
        (_) => const ReviewsListScreen(
          jeeberId: reviewsListScreenJeeberId,
          repository: ReviewsListScreenFailingRepository(
            ReviewsFailure.unauthorized,
            UnauthorizedFailure(),
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
      CatalogState(
        'Load failed (LR-05)',
        (_) => _settingsOverProfileRepository(
          const SettingsScreenThrowingProfileRepository(),
        ),
      ),
      CatalogState(
        'Load failed — expired session (exit CTA, no Retry)',
        (_) => _settingsOverProfileRepository(
          const SettingsScreenThrowingProfileRepository(UnauthorizedFailure()),
        ),
      ),
      CatalogState(
        'Save failed — the optimistic name rolls back (LR-15)',
        (_) => _settingsOverProfileRepository(
          SettingsScreenSaveFailingProfileRepository(),
          afterLoad: (cubit) => cubit.saveProfile(name: 'Rejected edit'),
        ),
      ),
      CatalogState(
        'Loading — the read never lands',
        (_) => _settingsOverProfileRepository(
          const SettingsScreenSlowProfileRepository(),
        ),
      ),
      CatalogState(
        'Notification write failed (F11)',
        (_) => _settingsOverProfileRepository(
          SettingsScreenFakeProfileRepository(
            SettingsScreenPreviewFixtures.sampleProfile(),
          ),
          notificationStore: SettingsScreenFakeNotificationStore(
            writeFails: true,
          ),
          afterLoad: (cubit) => cubit.setNotification(NotificationCategory.offers, false),
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
      // M3-23: the cold read the screen never used to draw. `awaitLoad: false`
      // is what puts it on the pre-load frame instead of skipping past it.
      CatalogState(
        'Loading',
        (_) => const ProfileEditScreenPreviewHost(
          repository: ProfileEditScreenPendingLoadRepository(),
          awaitLoad: false,
          child: ProfileEditScreen(),
        ),
      ),
      // The only state that renders `profile_edit_remove_avatar_cta`, i.e. the
      // one place the destructive ink is visible.
      CatalogState(
        'Loaded — With Photo',
        (_) => _profileEditPreview(profileEditScreenPhotoProfile),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'LiveSettingsScreen',
    states: [
      // M3-37 owns only the two frames before `SettingsScreen` takes over, so
      // only those two are catalogued — the loaded body is R22's capture.
      CatalogState(
        'Loading',
        (_) => LiveSettingsScreen(
          snapshotLoader: () => Completer<Map<String, dynamic>>().future,
        ),
      ),
      CatalogState(
        'Error — Read Failed',
        (_) => LiveSettingsScreen(
          snapshotLoader: () => Future<Map<String, dynamic>>.error(
            StateError('capture: /v1/users/me unavailable'),
          ),
        ),
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
      CatalogState(
        'Malformed body',
        (_) => const NotificationPreferencesScreen(
          repository:
              NotificationPreferencesScreenThrowingRepository.malformedBody,
        ),
      ),
      CatalogState(
        'Unauthorized',
        (_) => const NotificationPreferencesScreen(
          repository:
              NotificationPreferencesScreenThrowingRepository.unauthorized,
        ),
      ),
      CatalogState(
        'Save failed — retry',
        (_) => const NotificationPreferencesScreen(
          cubitFactory: NotificationPreferencesScreenSaveFailureCubit.new,
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
