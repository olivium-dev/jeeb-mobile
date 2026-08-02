import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../notification_prefs/application/notification_prefs_cubit.dart';
import '../../../notification_prefs/domain/notification_prefs_repository.dart';
import '../../../notification_prefs/presentation/notification_prefs_screen.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/notification_preferences_screen_fixtures.dart';

/// Wrapper that creates the [NotificationPrefsCubit] with the DI-registered
/// [NotificationPrefsRepository] and provides it to [NotificationPrefsScreen].
///
/// T-MOB-026: cubit is now server-first (GET on mount, debounced PATCH on
/// toggle) rather than SharedPreferences-only.
class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key, this.repository});

  /// DT-04 catalog / test seam: overrides the DI-registered repository.
  /// Production callers leave this null and get the unchanged
  /// `sl<NotificationPrefsRepository>()` resolution.
  final NotificationPrefsRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(
        repository: repository ?? sl<NotificationPrefsRepository>(),
      ),
      child: const NotificationPrefsScreen(),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/settings/notification_preferences_screen_preview_test.dart
// ===========================================================================
//
// [NotificationPreferencesScreen] is a two-line wrapper: it builds a
// [NotificationPrefsCubit] over the DI-registered repository and hands it to
// [NotificationPrefsScreen], which is the surface these previews are really
// about. So four things differ from a widget preview.
//
// 1. It owns a `Scaffold` (via the inner screen's OMDS app bar + body) and
//    [jeebPreviewHost] wraps every child in one as well, so the canvas shows
//    two nested Scaffolds. The inner one is the real surface; the outer
//    contributes a background and a `SafeArea`.
//
// 2. The canvas box is a real device, not the harness's default 390x200 — six
//    settings rows under an app bar cannot be judged in a 200 pt strip. The
//    device itself is pinned INSIDE the fixture (a `MediaQuery` override plus
//    a `SizedBox`), because the canvas honours `size:` but the render tests
//    pump onto a fixed 800 x 600 surface: a state that merely ASKED for a
//    320 x 568 canvas would be measured at 800 x 600 and the compact window
//    would silently become the phone one.
//
// 3. State is driven the only way this screen allows — through the
//    `repository:` seam (40_GUARDRAILS_ARCH §5.4), with the fakes shared with
//    the Screen Catalog entry
//    (`lib/devtool/catalog/fixtures/notification_preferences_screen_fixtures.dart`).
//    The wrapper builds its own cubit internally, so a state is reachable here
//    only if some canned repository behaviour produces it. No preview
//    constructs a `DioNotificationPrefsRepository` and the
//    `sl<NotificationPrefsRepository>()` branch is never reached — network-free
//    by construction rather than by the guard in [jeebPreviewHost].
//
// 4. Its one affordance navigates. `_onBack` calls `context.canPop()`, a
//    GoRouter extension that THROWS when no `Router` is in scope, and the
//    screen paints fine without one — so a naive host looks correct right up
//    until someone taps the arrow. The fixture host seeds the production
//    stack: `settings-notifications` is declared as a child of `/settings`, so
//    LiveSettingsScreen sits underneath and the arrow pops to it.
//
// Every loaded state renders the SAME fifteen ARB strings — the two section
// headers, four category rows with their subtitles, and the locked
// transactional row are all static, and a fixture changes only the value of
// four `Switch`es. "Did it render" is therefore a weak question here, so each
// preview is captioned with the fixture it is wired to (the string the render
// test pins) and the test group below asserts the switch values, which is the
// only thing that actually differs.
//
// What these previews surfaced in the screen:
//
//  * **The typed load failure is computed and then thrown away.** The cubit
//    maps the repository's `NotificationPrefsFailure` onto a
//    `NotificationPrefsFailureView` and stores it on `NotificationPrefsError`
//    — and `_ErrorView` never reads it. `network` and `unknown` render the
//    same `notificationPrefsLoadError` string, so an offline user is told
//    "Couldn't load your notification preferences." with no hint that the
//    problem is their connection, and is offered a Retry that will fail the
//    same way until the network comes back. Pinned by the render test: two
//    fixtures failing for different reasons are byte-identical on screen.
//  * **Retry gives no feedback that it was pressed.** `_ErrorView`'s CTA is
//    `cubit.load`, which emits `NotificationPrefsLoading` — so the failed
//    surface is replaced by a bare centered spinner with no app-bar progress,
//    no disabled CTA and no message. On a slow connection the error copy the
//    user was reading simply disappears for the duration.
//  * **`NotificationPrefsLoaded.isSaving` is emitted and never rendered.** The
//    cubit sets it before every debounced PATCH; the word `isSaving` does not
//    appear anywhere in `notification_prefs_screen.dart`. The switch stays
//    interactive and unmarked while the write is in flight, so the only
//    feedback a user ever gets from a save is the snackbar that appears when
//    it FAILS — success is silent and indistinguishable from not having saved.
//    [notificationPreferencesScreenSaveFails] is the state where that matters:
//    tap a row and it flips instantly, sits there for the 500 ms debounce plus
//    the round trip, then flips back under a snackbar.
//  * **Back has two answers.** The arrow calls
//    `context.goNamed('customer-profile')` when there is nothing to pop, and
//    the screen's dartdoc states "Back → `customer-profile`". But
//    `settings-notifications` is declared as a CHILD of `/settings` and
//    go_router materializes a page for every matched ancestor with a builder,
//    so `canPop()` is true on every route into this screen and the arrow
//    always pops to LiveSettingsScreen. The `customer-profile` branch is
//    unreachable — and were it reachable it would disagree with the router's
//    own registered fallback for this route,
//    `AppRouter.backFallbacks['settings-notifications'] == '/settings'`, which
//    is what the SYSTEM back gesture uses via `RootAwareBackScope`. The render
//    test pins both destinations.
//  * **The locked Security section is conditional on a flag nothing can turn
//    off.** `_PrefsBody` renders it behind `if (prefs.transactionalLocked)`,
//    while `DioNotificationPrefsRepository._parse` hardcodes
//    `transactionalLocked: true` on both of its parse paths. The branch is
//    dead in production, and [notificationPreferencesScreenTransactionalUnlocked]
//    shows what it costs if it ever wakes up: the whole section disappears,
//    taking `notif_prefs_transactional_lock_icon` — an id JM-058 AC2 and the
//    on-device jm-058 flow both assert — out of the semantics tree with it.
//  * **At the accessibility ceiling the locked row is not merely below the
//    fold, it is not BUILT.** On a 320 x 568 device at 200% text the body
//    carries 1618 pt of scroll and the `ListView` stops building past its
//    viewport plus cache extent: four of the five rows exist on arrival and
//    `notif_prefs_transactional_lock_icon` is absent from the widget tree AND
//    from the semantics tree until the user scrolls to it. A driver or a
//    screen reader querying the id the AC publishes finds nothing. (Treat the
//    exact extent with care — `flutter_test` renders every glyph as a square of
//    the font size, which makes English roughly twice as wide as Inter does, so
//    the real device scrolls less. What is not a font artifact is the ordering:
//    the locked row is last, so it is the first thing to fall off.)
//  * The good news, recorded because it is cheap to lose: NOTHING overflows.
//    Every state renders clean in EN and in AR, at 100% and at 200% text, on a
//    390 x 844 phone and on a 320 x 568 one. `SwitchListTile` keeps the title
//    column inside the tile's own constraints, so the copy wraps instead of
//    pushing the switch off the trailing edge, and the body is a `ListView`
//    that simply grows a scroll extent.

/// The canvas box for a whole screen: a real phone, plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _notificationPreferencesScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on, framed the
/// same way.
const Size _notificationPreferencesScreenCompactCanvas = Size(332, 612);

/// Every state is the same screen behind the same app bar, differing only in
/// the fake repository it is constructed with — so each one names itself.
///
/// The `NotificationPreferencesScreen(...)` is constructed HERE rather than
/// inside the fixture host on purpose: `tool/preview_coverage.dart` credits a
/// section only when it literally builds the widget its previews are named
/// after, and it keeps the fixture library free of a circular import back into
/// this one.
Widget _notificationPreferencesScreenHosted(
  NotificationPreferencesScreenFakeRepository repository, {
  required String caption,
  NotificationPreferencesScreenWindow window =
      NotificationPreferencesScreenWindows.phone,
}) =>
    NotificationPreferencesScreenPreviewHost(
      window: window,
      caption: caption,
      screen: NotificationPreferencesScreen(repository: repository),
    );

/// Cold start: `GET /v1/notifications/preferences` is on the wire.
///
/// The cubit emits `NotificationPrefsLoading` from `initState`, so this is what
/// every user sees first — a centered 48 pt spinner under a titled app bar,
/// with no skeleton of the rows that are about to appear and nothing to say
/// what is loading. The fake never resolves, so the state holds.
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
///
/// Matrixed because this is a stack of `title + subtitle | switch` rows and the
/// AR card is where the whole row mirrors — the switch has to land on the left
/// and the two-line text column on the right — while the 200% card is where the
/// six rows stop fitting a phone and the composition becomes a scroll. Both
/// hold: nothing overflows in either.
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
///
/// The nearest thing this screen has to an EMPTY state, and the one reading in
/// which the locked row is legible as a statement rather than as one more
/// switch that happens to be on: four grey, one on and unresponsive. It is also
/// the state that shows how little separates the two — the locked row differs
/// only by opacity, and at a glance it reads as a category the user simply
/// forgot to turn off.
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
///
/// The cubit classified it — `NotificationPrefsFailureView.network` — and
/// `_ErrorView` discards the classification, so this renders exactly what an
/// `unknown` failure renders: one generic line and a Retry. There is no
/// "check your connection" copy anywhere on the screen, and no state in which
/// the two failures can be told apart.
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
///
/// Identical to `Loaded · defaults` until you touch it, which is the point: the
/// screen renders no in-flight affordance at all (`NotificationPrefsLoaded.isSaving`
/// is emitted by the cubit and read by nothing), so a toggle flips instantly,
/// stays flipped through the 500 ms debounce and the round trip, then silently
/// flips BACK under an OMDS snackbar. This is the only preview in the file that
/// has to be tapped to show its state; the render test taps it.
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
///
/// The entire Security section disappears: the header, the always-on row, and
/// `notif_prefs_transactional_lock_icon` with them. That id is named in the
/// JM-058 AC and asserted by the on-device jm-058 flow, so this is the shape in
/// which the screen still "works" while the acceptance test goes red. Kept
/// visible precisely because `DioNotificationPrefsRepository._parse` hardcodes
/// the flag true on both parse paths today — nothing else in the repo
/// exercises this branch.
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
///
/// Five two-line rows and two section headers at 200% on a 320 x 568 device.
/// Nothing overflows — `SwitchListTile` wraps its title column inside the
/// tile's constraints instead of shoving the switch off the trailing edge —
/// and the composition simply becomes a long scroll (1618 pt of it under test,
/// behind a ~512 pt viewport). What it costs is reachability: only FOUR of the
/// five rows are built on arrival, because the `ListView` stops at its viewport
/// plus cache extent. The one that falls off is the last one — the locked
/// Security row — so `notif_prefs_transactional_lock_icon` is absent from the
/// widget tree AND from the semantics tree until the user scrolls, and it is
/// the id JM-058 AC2 publishes as the QA target. Pinned by the render test.
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
