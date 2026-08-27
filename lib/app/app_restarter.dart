import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/di/injection_container.dart';
import '../core/previews/jeeb_preview.dart';
import '../core/theme/app_theme.dart';

/// Rebuilds the whole app from scratch, in-process.
///
/// The Dev Tool changes settings that are only read during startup — the Server
/// URL is the motivating one: `configureDependencies` registers `Dio` as a LAZY
/// singleton over `DevBaseUrl.read(prefs)`, so once that `Dio` has been resolved
/// the base URL is fixed for the life of the process. Editing the setting and
/// returning to the app therefore changed nothing, which is why
/// `dev_settings_page.dart` tells the user to "Restart the app to apply" — an
/// instruction the app itself could not carry out.
///
/// iOS gives a process no way to relaunch itself, so a true restart is not
/// available. This is the closest faithful equivalent: tear the widget tree
/// down, reset the service locator, then run `Bootstrap.minimal()` again from a
/// fresh [JeebBootstrap]. Everything startup-scoped is rebuilt, including
/// `Dio`; only the process and its Flutter engine survive.
///
/// Ordering matters and is the whole reason this is a three-phase operation:
/// `configureDependencies` calls `sl.registerSingleton<SharedPreferences>`
/// UNGUARDED, so it throws if it runs while the previous registration is still
/// live. The tree must be fully unmounted BEFORE `sl.reset()`, and `sl.reset()`
/// must complete BEFORE the new tree mounts — otherwise a still-mounted widget
/// resolves a singleton that is being disposed underneath it.
class AppRestarter extends StatefulWidget {
  const AppRestarter({required this.child, super.key});

  final Widget child;

  /// Restarts the app if an [AppRestarter] is above [context].
  ///
  /// A no-op when there is none, which is the case in widget tests and in any
  /// build where the wrap is compiled out. Callers are dev-only affordances, so
  /// silently doing nothing is the right failure mode — never throw at a user
  /// who just tapped "close".
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestarterState>()?.restart();
  }

  /// Whether a restart is actually available above [context].
  static bool isAvailable(BuildContext context) =>
      context.findAncestorStateOfType<_AppRestarterState>() != null;

  @override
  State<AppRestarter> createState() => _AppRestarterState();
}

class _AppRestarterState extends State<AppRestarter> {
  Key _generation = UniqueKey();
  bool _tearingDown = false;
  bool _restartInFlight = false;

  Future<void> restart() async {
    // Re-entrancy guard: a double-tap on the close button must not interleave
    // two resets, which would race `sl.reset()` against a re-registration.
    if (_restartInFlight) return;
    _restartInFlight = true;

    // Phase 1 — unmount the entire app subtree. This disposes every cubit,
    // stream subscription and controller that holds a service-locator
    // reference, so nothing is left pointing at what phase 2 resets.
    setState(() => _tearingDown = true);

    // Wait for that frame to actually commit. `setState` only schedules; the
    // old elements are not disposed until the frame is built, so resetting
    // before this callback would reset while they are still live.
    final SchedulerBinding binding = SchedulerBinding.instance;
    await binding.endOfFrame;

    // Phase 2 — drop every registration so `configureDependencies` can run
    // again without tripping its unguarded `registerSingleton`.
    //
    // Guarded: `sl.reset()` runs every registered disposer, and a throwing
    // disposer must not strand the app. Without this, one bad `dispose` leaves
    // `_tearingDown` true forever and the user is left staring at the black
    // teardown surface with no way back — a far worse outcome than a singleton
    // that failed to close.
    try {
      await sl.reset();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'jeeb dev tool',
          context: ErrorDescription('disposing services during an app restart'),
        ),
      );
    }

    // Phase 3 — mount a fresh generation. The new key forces a new element and
    // therefore a new `_JeebBootstrapState`, whose `late final _bootstrap`
    // field runs `Bootstrap.minimal()` from the top.
    if (!mounted) {
      _restartInFlight = false;
      return;
    }
    setState(() {
      _generation = UniqueKey();
      _tearingDown = false;
      _restartInFlight = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tearingDown) {
      // Deliberately not the branded splash: this is a single frame with no
      // app tree mounted, and the splash resolves theme/localization that the
      // reset is about to invalidate. The colour comes from the theme rather
      // than a literal — `no_raw_semantic_colors_test` forbids raw hex colour
      // literals outside `lib/core/theme/`, and there is no `BuildContext`
      // carrying a theme here because the tree above us is gone.
      return ColoredBox(color: AppTheme.midnight().scaffoldBackgroundColor);
    }
    return KeyedSubtree(key: _generation, child: widget.child);
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

/// The single frame between "tear the app down" and "mount it again".
///
/// Worth a preview because it IS a user-visible state — every `Apply & Restart`
/// paints it — and because getting its colour wrong reads as a crash-to-black
/// rather than a deliberate restart.
@JeebPreview(
  group: 'app',
  name: 'Restart · teardown frame',
  size: Size(390, 844),
)
Widget appRestarterTeardownFrame() =>
    ColoredBox(color: AppTheme.midnight().scaffoldBackgroundColor);

/// The idle state: [AppRestarter] is transparent until a restart is requested,
/// so its child must render byte-identically to an unwrapped tree.
@JeebPreview(
  group: 'app',
  name: 'Restart · idle passthrough',
  size: Size(390, 844),
)
Widget appRestarterIdle() => AppRestarter(
  child: ColoredBox(color: AppTheme.midnight().colorScheme.surface),
);
