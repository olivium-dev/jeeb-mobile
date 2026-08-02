// Shared dev-only fixtures for `NotificationPrefsScreen` (JM-058, D64).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_07_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/notification_prefs/presentation/notification_prefs_screen.dart`.
//
// The catalog owned three private fakes (`_FakeNotificationPrefsRepository`,
// `_NeverLoadingNotificationPrefsRepository`,
// `_FailingNotificationPrefsRepository`) driving three states — Loading /
// Loaded / Load Error. Copying them into the preview section would have given
// the two surfaces two different notions of "the designed state", free to
// drift; both now come through this file instead.
//
// ## Why this file is mostly an `export`
//
// `NotificationPrefsScreen` is the surface. `NotificationPreferencesScreen`
// (`lib/features/settings/presentation/screens/`) is a five-line wrapper that
// builds a `NotificationPrefsCubit` over the DI-registered repository and hands
// it to this same screen — so the two screens are mocked from the same three
// facts: what `fetch()` resolves to, whether it throws, and whether the
// debounced PATCH throws. `../fixtures/notification_preferences_screen_fixtures.dart`
// already carries exactly those fakes, the two device windows, and the Router
// host the back arrow needs, all public and all already exercised by a render
// test.
//
// Re-declaring them here would have created the second copy this whole
// arrangement exists to prevent — two `NotificationPrefsRepository` fakes,
// diverging the first time one of them learned a new behaviour. So this file
// re-exports them under their existing names and adds only the two things the
// INNER screen needs and the wrapper's file cannot provide:
//
//   * [notificationPrefsScreenSeeded] — the `BlocProvider` seam. The wrapper
//     builds the cubit itself; the bare screen does not, it just
//     `context.read`s one in `initState`, so every surface that mounts it
//     directly has to supply one.
//   * [notificationPrefsScreenCatalogPrefs] — the exact snapshot the Screen
//     Catalog's `Loaded` state has always rendered, which is NOT the model's
//     default (`wallet` is off in the catalog and on by default).
//
// Everything here is local: no fixture constructs `DioNotificationPrefsRepository`
// and none of them reaches GetIt, so both surfaces are network-free by
// construction rather than merely by the `CatalogNetworkGuard` their hosts
// install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/notification_prefs/application/notification_prefs_cubit.dart';
import '../../../features/notification_prefs/domain/notification_prefs_model.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';

// The repositories (`NotificationPreferencesScreenFakeRepository`,
// `NotificationPreferencesScreenPendingRepository`), the canned snapshots
// (`…DefaultPrefs`, `…AllOffPrefs`, `…UnlockedPrefs`), the device windows and
// the Router-carrying `NotificationPreferencesScreenPreviewHost` all live next
// door and are shared verbatim — see the header. Importers of THIS file get
// them without a second import.
export 'notification_preferences_screen_fixtures.dart';

/// The snapshot the Screen Catalog's `Loaded` state has always shown: offers
/// and order status on, wallet and marketing off.
///
/// Deliberately not [NotificationPrefs]'s own defaults — those turn `wallet`
/// ON — because this constant exists to keep the designer-facing catalog
/// rendering byte-for-byte what it rendered before its fakes were extracted.
/// It doubles as the one loaded state in which the four category switches are
/// not all the same value, which is the only way to see at a glance that each
/// row is bound to its own field.
const NotificationPrefs notificationPrefsScreenCatalogPrefs = NotificationPrefs(
  categories: NotificationCategoryPrefs(
    offers: true,
    orderStatus: true,
    wallet: false,
    marketing: false,
  ),
);

/// Mounts [child] — a `NotificationPrefsScreen` — over a [NotificationPrefsCubit]
/// built on [repository].
///
/// The screen has no ctor seam of its own (40_GUARDRAILS_ARCH §5.4 is satisfied
/// one level up, by `NotificationPreferencesScreen`): `initState` calls
/// `context.read<NotificationPrefsCubit>().load()`, so a bare
/// `NotificationPrefsScreen()` throws `ProviderNotFoundException` on mount.
/// This is the seam, and a scripted repository is the only way to drive the
/// sealed state machine — `Loading` while `fetch()` is unresolved, `Loaded` on
/// success, `Error` on a typed failure.
///
/// The cubit keeps its PRODUCTION 500 ms debounce. A preview that shortened it
/// would render a save round trip nobody can actually see.
Widget notificationPrefsScreenSeeded({
  required NotificationPrefsRepository repository,
  required Widget child,
}) {
  return BlocProvider<NotificationPrefsCubit>(
    create: (_) => NotificationPrefsCubit(repository: repository),
    child: child,
  );
}
