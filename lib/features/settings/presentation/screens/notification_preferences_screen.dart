import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../notification_prefs/application/notification_prefs_cubit.dart';
import '../../../notification_prefs/domain/notification_prefs_repository.dart';
import '../../../notification_prefs/presentation/notification_prefs_screen.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/notification_preferences_screen_fixtures.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({
    super.key,
    this.repository,
    this.cubitFactory,
  });

  final NotificationPrefsRepository? repository;

  /// The provider closes this factory's cubit; the screen still calls load.
  final NotificationPrefsCubit Function()? cubitFactory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationPrefsCubit>(
      create: (_) =>
          cubitFactory?.call() ??
          NotificationPrefsCubit(
            repository: repository ?? sl<NotificationPrefsRepository>(),
          ),
      child: const NotificationPrefsScreen(),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _notificationPreferencesScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on, framed the
/// same way.
const Size _notificationPreferencesScreenCompactCanvas = Size(332, 612);

/// Every state is the same screen behind the same app bar, differing only in
/// the fake repository it is constructed with — so each one names itself.
Widget _notificationPreferencesScreenHosted(
  NotificationPreferencesScreenFakeRepository repository, {
  required String caption,
  NotificationPreferencesScreenWindow window =
      NotificationPreferencesScreenWindows.phone,
}) => NotificationPreferencesScreenPreviewHost(
  window: window,
  caption: caption,
  screen: NotificationPreferencesScreen(repository: repository),
);

/// Cold start: `GET /v1/notifications/preferences` is on the wire.
/// The cubit emits `NotificationPrefsLoading` from `initState`, so this is what
@JeebPreview(
  group: 'settings',
  name: 'Loading',
  size: _notificationPreferencesScreenPhoneCanvas,
)
Widget notificationPreferencesScreenLoading() =>
    _notificationPreferencesScreenHosted(
      const NotificationPreferencesScreenPendingRepository(),
      caption: 'Loading · phone 390 × 844',
    );

/// The happy path, and the shape the JM-058 ACs are written against: offers,
/// order status and wallet on, marketing off, transactional locked.
@JeebPreview(
  group: 'settings',
  name: 'Loaded · defaults',
  size: _notificationPreferencesScreenPhoneCanvas,
  matrix: true,
)
Widget notificationPreferencesScreenLoaded() =>
    _notificationPreferencesScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenDefaultPrefs,
      ),
      caption: 'Loaded · defaults · phone 390 × 844',
    );

/// Everything the user is allowed to turn off, turned off.
/// The nearest thing this screen has to an EMPTY state, and the one reading in
@JeebPreview(
  group: 'settings',
  name: 'Loaded · everything off',
  size: _notificationPreferencesScreenPhoneCanvas,
)
Widget notificationPreferencesScreenAllOff() =>
    _notificationPreferencesScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenAllOffPrefs,
      ),
      caption: 'Loaded · everything off · phone 390 × 844',
    );

/// The initial fetch failed with a typed `network` failure.
/// The cubit classified it — `NotificationPrefsFailureView.network` — and
@JeebPreview(
  group: 'settings',
  name: 'Error · fetch failed',
  size: _notificationPreferencesScreenPhoneCanvas,
)
Widget notificationPreferencesScreenError() =>
    _notificationPreferencesScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        fetchFailure: NotificationPrefsFailure.network,
      ),
      caption: 'Error · fetch failed · phone 390 × 844',
    );

/// Loaded, but the next PATCH will fail — the D30 optimistic-revert path.
/// Identical to `Loaded · defaults` until you touch it, which is the point: the
@JeebPreview(
  group: 'settings',
  name: 'Loaded · the save will fail',
  size: _notificationPreferencesScreenPhoneCanvas,
)
Widget notificationPreferencesScreenSaveFails() =>
    _notificationPreferencesScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenDefaultPrefs,
        saveFailure: NotificationPrefsFailure.network,
      ),
      caption: 'Loaded · the save will fail · phone 390 × 844',
    );

/// `transactionalLocked: false` — the branch `_PrefsBody` guards and the
/// gateway cannot currently produce.
@JeebPreview(
  group: 'settings',
  name: 'Loaded · transactional unlocked',
  size: _notificationPreferencesScreenPhoneCanvas,
)
Widget notificationPreferencesScreenTransactionalUnlocked() =>
    _notificationPreferencesScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenUnlockedPrefs,
      ),
      caption: 'Loaded · transactional unlocked · phone 390 × 844',
    );

/// The worst case the app supports: the smallest display AND the largest text.
/// Five two-line rows and two section headers at 200% on a 320 x 568 device.
@JeebPreview(
  group: 'settings',
  name: 'Loaded · compact · 200% text',
  size: _notificationPreferencesScreenCompactCanvas,
)
Widget notificationPreferencesScreenCompactLargeText() =>
    _notificationPreferencesScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenDefaultPrefs,
      ),
      caption: 'Loaded · defaults · compact 320 × 568 · 200% text',
      window: NotificationPreferencesScreenWindows.compactLargeText,
    );
