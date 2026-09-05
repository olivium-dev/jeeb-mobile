// Shared dev-only fixtures for `BiometricLockScreen`.

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
const String biometricLockScreenShellStandInLabel =
    'app shell (preview stand-in)';

/// Where `biometric_unlock_use_password_link` lands: `/register`, the phone-OTP
/// re-auth entry. NOT a password screen — the email/password funnel was removed
const String biometricLockScreenRegisterStandInLabel =
    'phone-OTP registration (preview stand-in)';

/// The route the screen is held on, and the one the gate redirects off.
const String _biometricLockScreenLockRoute = '/lock';

/// A [BiometricGateway] that answers from a constructor flag instead of
/// `local_auth`.
/// The production default is `UnavailableBiometricGateway`, whose
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
  /// Recorded because it is the one piece of user-visible copy on this flow
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

/// A gateway that THROWS the way `LocalAuthBiometricGateway` now does for an
/// OS refusal — the R3 proof that no signature had to widen (UX-24).
class BiometricLockScreenThrowingGateway implements BiometricGateway {
  BiometricLockScreenThrowingGateway(this.failure, {this.available = true});

  final BiometricFailure failure;
  final bool available;

  int authenticateCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls += 1;
    throw BiometricAuthException(failure);
  }
}

/// An in-memory stand-in for [SharedPreferences].
/// [BiometricLockCubit] REQUIRES a [BiometricPreferenceRepositoryImpl] and a
/// [SharedPrefsPinRepository], both of which require a `SharedPreferences`. The
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
/// DEV-ONLY. The emit happens in the constructor, before any surface has
class BiometricLockScreenSeededCubit extends BiometricLockCubit {
  /// [enrolled] and [pin] seed the preference store the way the dev-seam
  /// `jeeb.seam.session=biometric_enrolled` does, so a fixture that DOES call
  factory BiometricLockScreenSeededCubit(
    BiometricLockState seed, {
    BiometricLockScreenFakeGateway? gateway,
    bool enrolled = true,
    String? pin,
  }) {
    // One store behind both repositories, exactly as DI wires them: they read
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

/// A cubit over ANY gateway (including the throwing one), with the in-memory
/// preference + PIN stores behind it.
BiometricLockCubit biometricLockScreenCubitOver(
  BiometricGateway gateway, {
  bool enrolled = true,
  String? pin,
}) {
  final SharedPreferences prefs =
      BiometricLockScreenInMemoryPrefs(<String, Object>{
    BiometricPreferenceRepositoryImpl.kEnabledKey: enrolled,
    SharedPrefsPinRepository.kPinKey: ?pin,
  });
  return BiometricLockCubit(
    preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
    gateway: gateway,
    pinRepository: SharedPrefsPinRepository(prefs: prefs),
  );
}

/// The base every fixture starts from: the router gate is holding this user on
/// `/lock` and the authenticate action has not run.
const BiometricLockState _biometricLockScreenLocked = BiometricLockState(
  phase: BiometricLockPhase.locked,
);

/// The state a returning enrolled user lands in on cold start: held on `/lock`,
/// nothing in flight, nothing failed yet.
BiometricLockCubit biometricLockScreenLockedCubit() =>
    BiometricLockScreenSeededCubit(_biometricLockScreenLocked);

/// The platform biometric sheet is in flight: the CTA is disabled and the
/// cubit's own re-entrancy guard is armed.
BiometricLockCubit biometricLockScreenPromptingCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked.copyWith(
        prompt: BiometricPromptStatus.prompting,
      ),
    );

/// The biometric check failed or was declined: `phase` stays `locked` (the gate
/// still holds `/lock`) and the screen surfaces the failure hint plus a retry
BiometricLockCubit biometricLockScreenFailedCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked.copyWith(prompt: BiometricPromptStatus.failed),
    );

/// Locked, with a gateway that will SAY YES — the only way to review the AC2
/// success path, which the screen itself does not implement.
BiometricLockCubit biometricLockScreenSucceedingCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked,
      gateway: BiometricLockScreenFakeGateway(succeeds: true),
    );

/// The PIN-only enrolment: the user opted in, the device has NO usable
/// biometric hardware, and a local PIN is what made `evaluate()` treat them as
BiometricLockCubit biometricLockScreenPinOnlyCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked,
      gateway: BiometricLockScreenFakeGateway(available: false),
      pin: '1234',
    );

/// The sensor is cooling down: the OS will refuse every further attempt, so the
/// Retry pill must be dead and the password fallback promoted.
BiometricLockCubit biometricLockScreenLockedOutCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked.copyWith(
        prompt: BiometricPromptStatus.failed,
        failure: BiometricFailure.lockedOut,
      ),
      pin: '1234',
    );

/// Nothing is enrolled on this device — same terminal shape, different copy.
BiometricLockCubit biometricLockScreenNotEnrolledCubit() =>
    BiometricLockScreenSeededCubit(
      _biometricLockScreenLocked.copyWith(
        prompt: BiometricPromptStatus.failed,
        failure: BiometricFailure.notEnrolled,
      ),
      pin: '1234',
    );

/// One simulated device window to render [BiometricLockScreen] in.
/// The frame has to be pinned by the fixture rather than left to the canvas
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
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
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
  /// This screen renders the SAME strings in several of its states — `locked`
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
  /// The Screen Catalog moves between states in place — its picker replaces
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
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// Turns the fixture cubit's stream into the `Listenable` `GoRouter` wants.
/// The app builds the same thing (`_CubitRefreshListenable` in
/// `app_router.dart`); it is private there, and re-deriving it here keeps this
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
/// It only has to exist and be identifiable, so an exit demonstrably reaches a
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
