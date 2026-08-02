// Shared dev-only fixtures for `NotificationPreferencesScreen` (JM-058, D64).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/notification_prefs/domain/notification_prefs_model.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Canned [NotificationPrefsRepository] — `fetch()` resolves to [prefs] and
/// `save()` echoes the categories back the way the gateway's PATCH does. No
/// Dio, no GetIt, no network.
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
  final NotificationPrefsFailure? fetchFailure;

  /// When non-null the debounced PATCH throws instead of confirming, which is
  /// what drives the D30 revert + the save-error snackbar. Only reachable by
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
/// The cubit emits `loading` from `load()` and leaves it only when the future
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

/// The shape a fresh account comes back with: the three operational categories
/// on, marketing off (the consent-friendly default the model documents), and
const NotificationPrefs notificationPreferencesScreenDefaultPrefs =
    NotificationPrefs();

/// Every category the user is allowed to turn off, turned off.
/// The nearest thing this screen has to an EMPTY state — there is no list to be
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
/// `_PrefsBody` renders the whole Security section behind
const NotificationPrefs notificationPreferencesScreenUnlockedPrefs =
    NotificationPrefs(transactionalLocked: false);

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
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
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
  static const NotificationPreferencesScreenWindow compactLargeText =
      NotificationPreferencesScreenWindow(
    size: Size(320, 568),
    textScale: 2,
  );
}

/// Where the app-bar back arrow lands when there is nothing to pop: the
/// screen's own `context.goNamed('customer-profile')` fallback.
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
  /// This screen's copy is identical in every loaded state — only `Switch`
  final String? caption;

  /// Whether `/settings` sits underneath — the PRODUCTION stack, and the
  /// default.
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
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}
