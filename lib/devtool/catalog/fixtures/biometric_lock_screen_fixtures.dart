// Shared dev-only fixtures for `BiometricLockScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_01_entries.dart`, feature
//     `biometric_auth`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/biometric_auth/presentation/biometric_lock_screen.dart`.
//
// The catalog owned a private `_SeededBiometricLockCubit` and three inline
// `BlocProvider.value` states. Copying that into the preview section would have
// given the two surfaces two different notions of "the failed state", free to
// drift — and the catalog is the one a designer signs off against. Both
// surfaces now build through [BiometricLockScreenPreviewHost].
//
// ## Why the states are SEEDED
//
// `BiometricLockScreen` has no injectable seam of its own: it reads its
// [BiometricLockCubit] off the ambient `BlocProvider` — deliberately, because
// the router watches that SAME instance in its `refreshListenable` — and
// renders whatever [BiometricLockState] it finds. [BiometricLockCubit] has no
// `seed:` constructor either, so the states worth reviewing are reachable from
// outside only through a real platform round-trip:
//
//   * `prompting` exists only while a real `gateway.authenticate` future is in
//     flight — on a simulator there is no biometric hardware to keep it there;
//   * `failed` needs a gateway that says no at exactly the right moment.
//
// [BiometricLockScreenSeededCubit] is a DEV-ONLY subclass that emits one fixed
// state at construction, through the `emit` bloc marks `@protected` (i.e.
// visible to subclasses). It is not a production seam and it adds none to the
// screen: the screen still only ever sees a `BiometricLockCubit` on a provider.
//
// ## Network-free, DI-free, keystore-free
//
// The catalog's old seed reached into GetIt for `sl<SharedPreferences>()` on
// the grounds that prefs are local device storage. True inside the running app,
// and unavailable everywhere else: a preview canvas and a `flutter test` process
// have no DI graph and no platform channel, so that seed could only ever be
// built from inside the app. [BiometricLockScreenInMemoryPrefs] answers from a
// plain map instead, which makes the same designed states buildable from all
// three surfaces. Nothing is lost — every state here is emitted directly, so
// the preference/PIN repositories are never read.
//
// The gateway is [BiometricLockScreenFakeGateway], which returns a canned
// answer without touching `local_auth`, and records the reason string the cubit
// hands the OS dialog so a test can inspect it.
//
// ## Why the fixtures mount a ROUTER as well as a cubit
//
// Two of the screen's behaviours are pure navigation and invisible in a bare
// host:
//
//   1. `biometric_unlock_use_password_link` calls `context.goNamed('register')`,
//      which THROWS with no `GoRouter` in scope. The screen builds fine without
//      one, so a naive host looks correct right up until someone taps it — and
//      inside the running app a bare host is worse than that: the tap would
//      steer the REAL app router out of the Dev Tool.
//   2. The success path (AC2) is not implemented on the screen at all. The
//      screen never navigates on unlock; the central gate in `app_router.dart`
//      redirects `/lock` → `/` the instant `phase != locked`. A fixture without
//      that gate would show "nothing happens" on a successful authenticate and
//      be lying by omission.
//
// So the host mounts a local [GoRouter] carrying the same two redirect rules the
// app's gate uses (`app_router.dart`, the block under "Biometric gate
// (T-mobile-005)"), driven by the fixture's own cubit. `Router.withConfig` is
// exactly what `MaterialApp.router` does internally, so this adds a Router and
// nothing else — ambient theme, locale and text scale still come from above.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../../../features/biometric_auth/domain/biometric_gateway.dart';
import '../../../features/settings/data/repositories/biometric_preference_repository_impl.dart';

/// Where the fixture's gate lands a released user — the app shell, i.e. the
/// AC2 success destination (`/` → last-used tab, D75).
///
/// Public so the render test can tell "the unlock released the gate" apart from
/// "the screen is still on /lock".
const String biometricLockScreenShellStandInLabel =
    'app shell (preview stand-in)';

/// Where `biometric_unlock_use_password_link` lands: `/register`, the phone-OTP
/// re-auth entry. NOT a password screen — the email/password funnel was removed
/// in JEBV4-199, which is the whole reason the link's copy no longer matches its
/// destination.
///
/// Public so the render test can pin where the "Use password instead" tap
/// actually goes.
const String biometricLockScreenRegisterStandInLabel =
    'phone-OTP registration (preview stand-in)';

/// The route the screen is held on, and the one the gate redirects off.
const String _biometricLockScreenLockRoute = '/lock';

/// A [BiometricGateway] that answers from a constructor flag instead of
/// `local_auth`.
///
/// The production default is `UnavailableBiometricGateway`, whose
/// `authenticate` hard-returns `false` — usable for the failure states and
/// useless for the success path, which is the one the screen does not implement
/// itself and therefore the one most worth demonstrating.
class BiometricLockScreenFakeGateway implements BiometricGateway {
  BiometricLockScreenFakeGateway({
    this.available = true,
    this.succeeds = false,
  });

  /// What `isAvailable()` reports — i.e. whether this device has usable
  /// biometric hardware. Only read by `evaluate()`, which no fixture calls.
  final bool available;

  /// What `authenticate()` reports. `false` models a declined/failed check.
  final bool succeeds;

  /// The reason string the cubit handed the OS dialog on the last call.
  ///
  /// Recorded because it is the one piece of user-visible copy on this flow
  /// that never passes through a `Text` widget, so no rendering — preview,
  /// golden or screenshot — can show it.
  String? lastReason;

  /// How many times the CTA reached the platform.
  int authenticateCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls += 1;
    lastReason = reason;
    return succeeds;
  }
}

/// An in-memory stand-in for [SharedPreferences].
///
/// [BiometricLockCubit] REQUIRES a [BiometricPreferenceRepositoryImpl] and a
/// [SharedPrefsPinRepository], both of which require a `SharedPreferences`. The
/// real one is async (`getInstance()`) and platform-channel backed — neither of
/// which a synchronous `Widget Function()` preview can have. This answers from a
/// plain map, so construction is synchronous and a write is a map write.
class BiometricLockScreenInMemoryPrefs implements SharedPreferences {
  BiometricLockScreenInMemoryPrefs([Map<String, Object>? seed])
      : _store = <String, Object>{...?seed};

  final Map<String, Object> _store;

  @override
  Object? get(String key) => _store[key];

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  double? getDouble(String key) => _store[key] as double?;

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  String? getString(String key) => _store[key] as String?;

  @override
  List<String>? getStringList(String key) =>
      (_store[key] as List<String>?)?.toList();

  @override
  Set<String> getKeys() => _store.keys.toSet();

  @override
  bool containsKey(String key) => _store.containsKey(key);

  @override
  Future<bool> setBool(String key, bool value) => _put(key, value);

  @override
  Future<bool> setDouble(String key, double value) => _put(key, value);

  @override
  Future<bool> setInt(String key, int value) => _put(key, value);

  @override
  Future<bool> setString(String key, String value) => _put(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _put(key, value);

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _store.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}

  Future<bool> _put(String key, Object value) async {
    _store[key] = value;
    return true;
  }
}

/// A [BiometricLockCubit] that starts in [seed] instead of the cold
/// `disabled` / `idle` default.
///
/// DEV-ONLY. The emit happens in the constructor, before any surface has
/// subscribed, so no listener sees the seed as a TRANSITION — which matters
/// here because the fixture's router gate is driven by exactly those
/// transitions.
///
/// Everything else about the cubit is real: `authenticate`,
/// `usePasswordFallback` and `evaluate` run the production code against the
/// local fakes.
class BiometricLockScreenSeededCubit extends BiometricLockCubit {
  /// [enrolled] and [pin] seed the preference store the way the dev-seam
  /// `jeeb.seam.session=biometric_enrolled` does, so a fixture that DOES call
  /// `evaluate()` reaches the same verdict the app would.
  factory BiometricLockScreenSeededCubit(
    BiometricLockState seed, {
    BiometricLockScreenFakeGateway? gateway,
    bool enrolled = true,
    String? pin,
  }) {
    // One store behind both repositories, exactly as DI wires them: they read
    // different keys out of the same `SharedPreferences`.
    final SharedPreferences prefs =
        BiometricLockScreenInMemoryPrefs(<String, Object>{
      BiometricPreferenceRepositoryImpl.kEnabledKey: enrolled,
      SharedPrefsPinRepository.kPinKey: ?pin,
    });
    return BiometricLockScreenSeededCubit._(
      seed,
      gateway ?? BiometricLockScreenFakeGateway(),
      prefs,
    );
  }

  BiometricLockScreenSeededCubit._(
    BiometricLockState seed,
    BiometricLockScreenFakeGateway gateway,
    SharedPreferences prefs,
  )   : fakeGateway = gateway,
        super(
          preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
          gateway: gateway,
          pinRepository: SharedPrefsPinRepository(prefs: prefs),
        ) {
    emit(seed);
  }

  /// The gateway this cubit drives, exposed so a test can read the reason
  /// string the cubit handed the OS dialog. Never used by a rendering.
  final BiometricLockScreenFakeGateway fakeGateway;
}

/// The base every fixture starts from: the router gate is holding this user on
/// `/lock` and the authenticate action has not run.
const BiometricLockState _biometricLockScreenLocked = BiometricLockState(
  phase: BiometricLockPhase.locked,
);

/// The state a returning enrolled user lands in on cold start: held on `/lock`,
/// nothing in flight, nothing failed yet.
///
/// Also the catalog's `Awaiting authentication`.
BiometricLockCubit biometricLockScreenLockedCubit() =>
    BiometricLockScreenSeededCubit(_biometricLockScreenLocked);

/// The platform biometric sheet is in flight: the CTA is disabled and the
/// cubit's own re-entrancy guard is armed.
///
/// Unreachable without a real pending future — `authenticate` sets `prompting`
/// and clears it the moment the gateway answers. Also the catalog's
/// `Prompting`.
BiometricLockCubit biometricLockScreenPromptingCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked.copyWith(
        prompt: BiometricPromptStatus.prompting,
      ),
    );

/// The biometric check failed or was declined: `phase` stays `locked` (the gate
/// still holds `/lock`) and the screen surfaces the failure hint plus a retry
/// label.
///
/// Also the catalog's `Failed attempt — retry`. This is the state with the most
/// copy on it, and the one whose copy points at an affordance the screen does
/// not have.
BiometricLockCubit biometricLockScreenFailedCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked.copyWith(prompt: BiometricPromptStatus.failed),
    );

/// Locked, with a gateway that will SAY YES — the only way to review the AC2
/// success path, which the screen itself does not implement.
///
/// Renders identically to [biometricLockScreenLockedCubit]; the difference is
/// what a tap on the CTA does. Used by the render test rather than by a preview
/// card.
BiometricLockCubit biometricLockScreenSucceedingCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked,
      gateway: BiometricLockScreenFakeGateway(succeeds: true),
    );

/// The PIN-only enrolment: the user opted in, the device has NO usable
/// biometric hardware, and a local PIN is what made `evaluate()` treat them as
/// able to challenge (`canChallenge = available || hasPin`).
///
/// Renders identically to [biometricLockScreenLockedCubit] — which is the
/// finding. Used by the render test rather than by a preview card.
BiometricLockCubit biometricLockScreenPinOnlyCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked,
      gateway: BiometricLockScreenFakeGateway(available: false),
      pin: '1234',
    );

/// One simulated device window to render [BiometricLockScreen] in.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test, and a centred column with room to spare
/// looks the same in every window.
@immutable
class BiometricLockScreenWindow {
  const BiometricLockScreenWindow({
    required this.label,
    required this.size,
    this.textScale,
  });

  /// Short name for the frame, used in the caption a preview paints above it.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class BiometricLockScreenWindows {
  BiometricLockScreenWindows._();

  /// The reference reading: an ordinary modern phone at default text size.
  static const BiometricLockScreenWindow phone = BiometricLockScreenWindow(
    label: 'Phone 390 × 844',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st gen
  /// class).
  static const BiometricLockScreenWindow compact = BiometricLockScreenWindow(
    label: 'Compact 320 × 568',
    size: Size(320, 568),
  );

  /// The accessibility ceiling on an ORDINARY phone.
  static const BiometricLockScreenWindow phoneLargeText =
      BiometricLockScreenWindow(
    label: 'Phone 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. The gate screen is not skippable, so this window is not an edge case
  /// — it is a user who cannot get into the app.
  static const BiometricLockScreenWindow compactLargeText =
      BiometricLockScreenWindow(
    label: 'Compact 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );
}

/// Hosts [BiometricLockScreen] in one designed state, with the ambient
/// [BiometricLockCubit] it reads and a local [GoRouter] carrying the app's
/// biometric-gate redirects.
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library, and
/// — the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `const BiometricLockScreen()` has to appear below the banner in the screen's
/// own file rather than in here.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — that is the form the Screen Catalog entry uses, where the device IS
/// the frame.
///
/// Stateful, and both the cubit and the router are built once and disposed with
/// the host: a cubit rebuilt per frame would re-seed the state under the person
/// looking at it, and a router rebuilt per frame would drop its history.
class BiometricLockScreenPreviewHost extends StatefulWidget {
  const BiometricLockScreenPreviewHost({
    required this.create,
    required this.screen,
    super.key,
    this.window,
    this.caption,
  });

  /// Builds the cubit under review. Called once per [State], and again only
  /// when the fixture itself changes (see `didUpdateWidget`) — never per frame.
  final BiometricLockCubit Function() create;

  /// The screen under review — `const BiometricLockScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final BiometricLockScreenWindow? window;

  /// Diagnostic caption painted above the frame, ignored when [window] is null.
  ///
  /// This screen renders the SAME strings in several of its states — `locked`
  /// and `prompting` differ only in a disabled tint, and three of the windows
  /// below hold the identical widget at a different size — so without a caption
  /// a render test cannot tell a preview wired to the wrong state from a correct
  /// one.
  final String? caption;

  @override
  State<BiometricLockScreenPreviewHost> createState() =>
      _BiometricLockScreenPreviewHostState();
}

class _BiometricLockScreenPreviewHostState
    extends State<BiometricLockScreenPreviewHost> {
  late BiometricLockCubit _cubit = widget.create();
  late _BiometricLockScreenGateSignal _gate =
      _BiometricLockScreenGateSignal(_cubit);
  late GoRouter _router = _buildRouter();

  /// Swapping the fixture must swap the STATE on screen.
  ///
  /// The Screen Catalog moves between states in place — its picker replaces
  /// this widget with another of the same type and no key, which Flutter treats
  /// as an update rather than a remount. Without this the [State] survives and
  /// keeps the first fixture's cubit, so the catalog goes on showing the
  /// previous designed state under the new state's name. `create` is a top-level
  /// function tear-off in every call site, so the identity comparison is stable.
  @override
  void didUpdateWidget(BiometricLockScreenPreviewHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.create == widget.create) return;
    _disposeStack();
    _cubit = widget.create();
    _gate = _BiometricLockScreenGateSignal(_cubit);
    _router = _buildRouter();
  }

  @override
  void dispose() {
    _disposeStack();
    super.dispose();
  }

  void _disposeStack() {
    _router.dispose();
    _gate.dispose();
    _cubit.close();
  }

  /// The app's biometric gate, reduced to the two redirects that concern this
  /// screen (`app_router.dart`, "Biometric gate (T-mobile-005)"):
  ///
  ///   * a `locked` phase pulls every other location back to `/lock`, and
  ///   * any other phase releases `/lock` onto `/`.
  ///
  /// The onboarding/session preconditions of the real gate are dropped: a user
  /// who is looking at this screen has already satisfied them.
  GoRouter _buildRouter() => GoRouter(
        initialLocation: _biometricLockScreenLockRoute,
        refreshListenable: _gate,
        redirect: (BuildContext context, GoRouterState state) {
          final BiometricLockPhase phase = _cubit.state.phase;
          final String loc = state.matchedLocation;
          if (phase == BiometricLockPhase.locked &&
              loc != _biometricLockScreenLockRoute) {
            return _biometricLockScreenLockRoute;
          }
          if (phase != BiometricLockPhase.locked &&
              loc == _biometricLockScreenLockRoute) {
            return '/';
          }
          return null;
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            name: 'shell',
            builder: (_, _) => const _BiometricLockScreenStandIn(
              label: biometricLockScreenShellStandInLabel,
            ),
          ),
          // The name `_usePasswordFallback` reaches for. Registered so the tap
          // resolves inside the fixture instead of throwing — and, inside the
          // running app, so it does not steer the REAL router out of Dev Tool.
          GoRoute(
            path: '/register',
            name: 'register',
            builder: (_, _) => const _BiometricLockScreenStandIn(
              label: biometricLockScreenRegisterStandInLabel,
            ),
          ),
          GoRoute(
            path: _biometricLockScreenLockRoute,
            name: 'biometric-lock',
            builder: (_, _) => widget.screen,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final Widget routed = BlocProvider<BiometricLockCubit>.value(
      value: _cubit,
      child: Router<Object>.withConfig(config: _router),
    );
    final BiometricLockScreenWindow? window = widget.window;
    if (window == null) return routed;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            widget.caption ?? window.label,
            // Forced LTR: a diagnostic caption, not shipped copy.
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
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
              // ZEROES padding for everything below it. Pinned here so the
              // screen's own `SafeArea` is a known quantity rather than an
              // inherited one.
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
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

    // Unbind both axes. The render tests pump onto 800 x 600 and every frame
    // here is taller than that; an `Align` + `SizedBox` would pass the host's
    // constraints down and the frame would be silently clamped to 600 pt — the
    // exact measurement the "does the column fit" assertions depend on not being
    // faked.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// Turns the fixture cubit's stream into the `Listenable` `GoRouter` wants.
///
/// The app builds the same thing (`_CubitRefreshListenable` in
/// `app_router.dart`); it is private there, and re-deriving it here keeps this
/// file from importing the router.
class _BiometricLockScreenGateSignal extends ChangeNotifier {
  _BiometricLockScreenGateSignal(BiometricLockCubit cubit) {
    _sub = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<BiometricLockState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// A page the fixture router can land on — the shell, or the registration
/// entry.
///
/// It only has to exist and be identifiable, so an exit demonstrably reaches a
/// page rather than emptying the Navigator.
class _BiometricLockScreenStandIn extends StatelessWidget {
  const _BiometricLockScreenStandIn({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            label,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
