// Shared dev-only fixtures for `NotificationPreferencesScreen` (JM-058, D64).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_10_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/settings/presentation/screens/notification_preferences_screen.dart`.
//
// The catalog owned two private fakes (`_FakeNotificationPrefsRepository`,
// `_PendingNotificationPrefsRepository`) driving three states — Loading /
// Loaded / Error. Copying them into the preview section would have given the
// two surfaces two different notions of "the designed state", free to drift;
// both now import this file instead.
//
// ## Everything here is local
//
// `NotificationPreferencesScreen` takes a `repository:` seam (40_GUARDRAILS_ARCH
// §5.4) and only falls through to `sl<NotificationPrefsRepository>()` when it is
// null, so neither surface ever constructs the Dio-backed
// `DioNotificationPrefsRepository` — network-free by construction, not merely by
// the `CatalogNetworkGuard` both hosts install.
//
// ## Why there is a window, and why the window is pinned HERE
//
// This screen renders the same fifteen ARB strings in every loaded state: the
// four category rows, their subtitles, the two section headers and the locked
// transactional row are all static, and what a fixture actually changes is the
// value of four `Switch`es. So "which state is this?" cannot be answered from
// the rendered copy, and the second axis — how much room the composition has —
// carries as much of the risk as the data does.
//
// [NotificationPreferencesScreenPreviewHost] therefore pins the frame itself (a
// `MediaQuery` override plus a `SizedBox`) and paints a caption naming the
// fixture. The frame has to be pinned by the fixture rather than left to the
// canvas `size:`, because the render tests in `test/previews/` pump onto a fixed
// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
// measured at 800 x 600 and every window would silently collapse into the same
// rendering. The caption is what lets a render test tell two otherwise
// byte-identical loaded states apart — the same device the
// `customer_wallet_stub_screen` fixtures use for the same reason.
//
// ## Why the host owns a Router
//
// `NotificationPrefsScreen._onBack` calls `context.canPop()` — a GoRouter
// extension that throws when no `Router` is in scope — and falls through to
// `context.goNamed('customer-profile')`. Neither call happens during `build`,
// so the screen PAINTS fine without a router and then dies the moment anyone
// taps the app-bar arrow: a canvas that looks right and is dead to the touch.
// The host supplies a real [GoRouter] carrying both destinations the back
// gesture can reach, so the surface is honest to tap and shows WHICH one it
// took.
//
// The stack it seeds is the PRODUCTION one. `app_router.dart` declares
// `settings-notifications` as a CHILD of `/settings`, and go_router builds a
// page for every matched ancestor that has a builder, so `/settings`
// (LiveSettingsScreen) is always underneath — after a Profile-tab
// `goNamed('settings-notifications')`, after a cold deep link, after a push
// tap. See [NotificationPreferencesScreenPreviewHost.poppable].
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/notification_prefs/domain/notification_prefs_model.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repositories
// ─────────────────────────────────────────────────────────────────────────────

/// Canned [NotificationPrefsRepository] — `fetch()` resolves to [prefs] and
/// `save()` echoes the categories back the way the gateway's PATCH does. No
/// Dio, no GetIt, no network.
///
/// `const`-constructible so the Screen Catalog can keep building
/// `const NotificationPreferencesScreen(repository: ...)`.
class NotificationPreferencesScreenFakeRepository
    implements NotificationPrefsRepository {
  const NotificationPreferencesScreenFakeRepository({
    this.prefs = const NotificationPrefs(),
    this.fetchFailure,
    this.saveFailure,
  });

  /// What `GET /v1/notifications/preferences` resolves to.
  final NotificationPrefs prefs;

  /// When non-null the initial fetch throws a
  /// [NotificationPrefsRepositoryException] carrying this typed failure — the
  /// way the live repository fails (guardrail §4: never a raw `DioException`).
  /// Drives `NotificationPrefsError`.
  final NotificationPrefsFailure? fetchFailure;

  /// When non-null the debounced PATCH throws instead of confirming, which is
  /// what drives the D30 revert + the save-error snackbar. Only reachable by
  /// actually toggling a row — the cubit never saves on its own.
  final NotificationPrefsFailure? saveFailure;

  @override
  Future<NotificationPrefs> fetch() async {
    final NotificationPrefsFailure? f = fetchFailure;
    if (f != null) throw NotificationPrefsRepositoryException(f);
    return prefs;
  }

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async {
    final NotificationPrefsFailure? f = saveFailure;
    if (f != null) throw NotificationPrefsRepositoryException(f);
    return prefs.copyWith(categories: categories);
  }
}

/// A read that never lands, holding the screen on `NotificationPrefsLoading`
/// for as long as the surface is open.
///
/// The cubit emits `loading` from `load()` and leaves it only when the future
/// completes, so this is the only way to inspect the centered `OmdsLoadingState`
/// without a real slow connection.
class NotificationPreferencesScreenPendingRepository
    extends NotificationPreferencesScreenFakeRepository {
  const NotificationPreferencesScreenPendingRepository();

  @override
  Future<NotificationPrefs> fetch() => Completer<NotificationPrefs>().future;

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) =>
      Completer<NotificationPrefs>().future;
}

// ─────────────────────────────────────────────────────────────────────────────
// Canned snapshots
// ─────────────────────────────────────────────────────────────────────────────

/// The shape a fresh account comes back with: the three operational categories
/// on, marketing off (the consent-friendly default the model documents), and
/// the transactional class locked.
///
/// This is what the catalog's `Loaded` state has always shown.
const NotificationPrefs notificationPreferencesScreenDefaultPrefs =
    NotificationPrefs();

/// Every category the user is allowed to turn off, turned off.
///
/// The nearest thing this screen has to an EMPTY state — there is no list to be
/// empty, so "opted out of everything" is the degenerate reading. It is also
/// the only state in which the locked Security row is legible as a statement
/// rather than as one more switch that happens to be on: four off, one on, and
/// that one greyed and unresponsive.
const NotificationPrefs notificationPreferencesScreenAllOffPrefs =
    NotificationPrefs(
  categories: NotificationCategoryPrefs(
    offers: false,
    orderStatus: false,
    wallet: false,
    marketing: false,
  ),
);

/// A snapshot with `transactionalLocked: false`.
///
/// `_PrefsBody` renders the whole Security section behind
/// `if (prefs.transactionalLocked)`, so this is the branch where it vanishes —
/// and with it `notif_prefs_transactional_lock_icon`, an id JM-058 AC2 and the
/// on-device jm-058 flow both assert. Worth keeping visible even though the
/// gateway cannot currently produce it: `DioNotificationPrefsRepository._parse`
/// hardcodes `transactionalLocked: true` on BOTH its parse paths, so the branch
/// is unreachable in production today and nothing but this fixture exercises it.
const NotificationPrefs notificationPreferencesScreenUnlockedPrefs =
    NotificationPrefs(transactionalLocked: false);

// ─────────────────────────────────────────────────────────────────────────────
// Window + host
// ─────────────────────────────────────────────────────────────────────────────

/// One simulated device window to render the screen in.
@immutable
class NotificationPreferencesScreenWindow {
  const NotificationPreferencesScreenWindow({
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class NotificationPreferencesScreenWindows {
  NotificationPreferencesScreenWindows._();

  /// The reference reading: an ordinary modern phone.
  static const NotificationPreferencesScreenWindow phone =
      NotificationPreferencesScreenWindow(size: Size(390, 844));

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class), at the accessibility ceiling. Six rows of two-line copy plus
  /// two section headers, in 568 pt — this is where the composition stops
  /// fitting.
  static const NotificationPreferencesScreenWindow compactLargeText =
      NotificationPreferencesScreenWindow(
    size: Size(320, 568),
    textScale: 2,
  );
}

/// Where the app-bar back arrow lands when there is nothing to pop: the
/// screen's own `context.goNamed('customer-profile')` fallback.
///
/// Public so the render test can assert the arrow reaches a page rather than
/// emptying the Navigator — and can pin WHICH page, since the router's own
/// registered fallback for this route
/// (`AppRouter.backFallbacks['settings-notifications']`) is `/settings`, not
/// this one.
const String notificationPreferencesScreenProfileStandInLabel =
    'customer-profile · preview stand-in';

/// Where a POP lands: the `/settings` parent this route is declared under.
const String notificationPreferencesScreenSettingsStandInLabel =
    'settings · preview stand-in';

/// A minimal, obviously-fake destination so a tap on the back arrow lands
/// somewhere legible instead of throwing or escaping into the real app.
class NotificationPreferencesScreenStandIn extends StatelessWidget {
  const NotificationPreferencesScreenStandIn({required this.label, super.key});

  /// What this stand-in is playing — read by the render tests to tell the two
  /// back destinations apart.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      body: Center(
        child: Text(
          label,
          // Forced LTR: a diagnostic, not shipped copy, and a latin route name
          // reorders visually inside an RTL paragraph.
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Hosts `NotificationPreferencesScreen` in one
/// [NotificationPreferencesScreenWindow], with a real `Router` above it so its
/// back arrow works.
///
/// The screen is INJECTED rather than constructed here, for two reasons: it
/// keeps this file free of a circular import back into the feature library,
/// and — the load-bearing one — `tool/preview_coverage.dart` credits a preview
/// section only when the section itself literally constructs the widget its
/// previews are named after.
///
/// Pass `window: null` (and `caption: null`) to render at the ambient window
/// with no frame and no caption — the form a Screen Catalog entry would use,
/// where the device IS the frame.
///
/// Stateful, and the [GoRouter] is built once and disposed with the host: a
/// router rebuilt on every frame would drop the stack `canPop()` reads.
/// `Router.withConfig` is exactly what `MaterialApp.router` does internally, so
/// this adds a Router and nothing else — the ambient theme, locale and text
/// scale still come from the preview host above it.
class NotificationPreferencesScreenPreviewHost extends StatefulWidget {
  const NotificationPreferencesScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.caption,
    this.poppable = true,
  });

  /// The screen under review — `NotificationPreferencesScreen(repository: …)`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final NotificationPreferencesScreenWindow? window;

  /// Caption painted above the frame, and the string each preview is pinned by.
  ///
  /// This screen's copy is identical in every loaded state — only `Switch`
  /// values change — so without a caption a render test cannot tell a preview
  /// wired to the wrong fixture from a correct one.
  final String? caption;

  /// Whether `/settings` sits underneath — the PRODUCTION stack, and the
  /// default.
  ///
  /// `app_router.dart` declares `settings-notifications` as a child of
  /// `/settings`, and go_router materializes a page for every matched ancestor
  /// that has a builder, so `canPop()` is true and the arrow POPS to
  /// LiveSettingsScreen.
  ///
  /// `false` declares the route FLAT instead — one page on the stack,
  /// `canPop()` false — which is the only way to reach the screen's
  /// `goNamed('customer-profile')` fallback at all. No stack the app can
  /// actually produce looks like this; it exists so a test can show where that
  /// branch would land if it ever fired.
  final bool poppable;

  @override
  State<NotificationPreferencesScreenPreviewHost> createState() =>
      _NotificationPreferencesScreenPreviewHostState();
}

class _NotificationPreferencesScreenPreviewHostState
    extends State<NotificationPreferencesScreenPreviewHost> {
  late final GoRouter _router = _buildRouter();

  GoRouter _buildRouter() {
    final GoRoute profile = GoRoute(
      path: '/profile/customer',
      // The name the screen itself reaches for on a cold stack.
      name: 'customer-profile',
      builder: (_, _) => const NotificationPreferencesScreenStandIn(
        label: notificationPreferencesScreenProfileStandInLabel,
      ),
    );
    final GoRoute notifications = GoRoute(
      path: 'notifications',
      name: 'settings-notifications',
      builder: (_, _) => widget.screen,
    );
    return GoRouter(
      initialLocation: '/settings/notifications',
      routes: <RouteBase>[
        profile,
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (_, _) => const NotificationPreferencesScreenStandIn(
            label: notificationPreferencesScreenSettingsStandInLabel,
          ),
          // Declaring the child only in the poppable case is what makes the
          // two stacks differ: as a CHILD, go_router materializes `/settings`
          // underneath and `canPop()` is true.
          routes: <RouteBase>[if (widget.poppable) notifications],
        ),
        if (!widget.poppable)
          GoRoute(path: '/settings/notifications', builder: (_, _) => widget.screen),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget routed = Router.withConfig(config: _router);
    final NotificationPreferencesScreenWindow? window = widget.window;
    if (window == null) return routed;

    final ThemeData theme = Theme.of(context);
    final String? caption = widget.caption;
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              caption,
              // Forced LTR: a diagnostic label, not shipped copy.
              textDirection: TextDirection.ltr,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
            // ZEROES `padding` for everything below it. Restoring it here is
            // what makes an inset window mean anything at all.
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: routed),
          ),
        ),
      ],
    );

    // Unbound on both axes. The render tests pump onto 800 x 600 and the phone
    // frame is taller than that; an `Align` + `SizedBox` would pass the host's
    // constraints down and the frame would be silently clamped to 600 pt,
    // which is exactly the measurement these previews depend on not being
    // faked.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}
