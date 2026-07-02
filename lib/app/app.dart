import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/accessibility/accessibility.dart';
import '../core/dev_seam/dev_seam.dart';
import '../core/dev_seam/session_seam_bootstrap.dart';
import '../core/locale/locale_cubit.dart';
import '../core/notifications/application/badge_count_cubit.dart';
import '../core/di/injection_container.dart';
import '../core/notifications/application/notification_dispatcher.dart';
import '../core/notifications/application/push_notification_handler.dart';
import '../core/notifications/application/offer_lifecycle_signals.dart';
import '../core/notifications/application/push_refresh_signals.dart';
import '../core/notifications/data/device_token_registrar.dart';
import '../core/notifications/data/firebase_messaging_transport.dart';
import '../core/notifications/data/push_device_registrar.dart';
import '../core/notifications/data/push_transport.dart';
import '../core/notifications/domain/notification_deep_link.dart';
import '../core/notifications/presentation/push_banner_host.dart';
import '../core/observability/crash_context_bridge.dart';
import '../core/observability/crash_reporter.dart';
import '../core/network/auth_token_store.dart';
import '../core/onboarding/onboarding_cubit.dart';
import '../core/role/role_availability_cubit.dart';
import '../core/role/role_cubit.dart';
import '../core/role/role_eligibility_cubit.dart';
import '../core/role/role_sync.dart';
import '../core/role/user_role.dart';
import '../core/router/app_router.dart';
import '../core/session/account_status_gate.dart';
import '../core/session/session_cubit.dart';
import '../core/session/session_gate.dart';
import '../core/session/session_state.dart';
import '../core/theme/app_theme.dart';
import '../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../features/biometric_auth/data/dev_biometric_gateway.dart';
import '../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../features/biometric_auth/domain/biometric_gateway.dart';
import '../features/settings/data/repositories/biometric_preference_repository_impl.dart';
import '../l10n/app_localizations.dart';

/// Root widget. Owns the global cubits (locale, role, onboarding), wires the
/// OMDS-themed `MaterialApp.router`, and lets Flutter apply RTL automatically
/// for Arabic. The router is built once per [JeebApp] instance so the
/// onboarding cubit it watches matches the one provided below.
///
/// Cold-start contract (T-mobile-047): only widget-tree-construction work
/// happens in `initState`. The push-notification chain (transport, handler,
/// dispatcher) is wired in `addPostFrameCallback` so first paint is never
/// blocked on FCM/APNs initialization.
class JeebApp extends StatefulWidget {
  const JeebApp({
    super.key,
    required this.preferences,
    this.crashReporter = const NoopCrashReporter(),
    this.pushTransport,
    this.firebaseInitializer,
    this.fcmTransportBuilder,
    this.pushDeviceRegistrar,
    this.biometricGateway,
    this.localizationsDelegateOverride,
    this.sessionGate,
  });

  final SharedPreferences preferences;

  /// Optional override for the localizations delegate. Production uses the
  /// default async [AppLocalizations.delegate] (a `rootBundle.loadString`
  /// round-trip); widget tests inject a synchronous delegate because that
  /// round-trip does not reliably complete under the headless `flutter test`
  /// binding (see `test/support/sync_app_localizations.dart`).
  final LocalizationsDelegate<AppLocalizations>? localizationsDelegateOverride;

  /// Per T-mobile-049, the crash reporter is built in bootstrap (so it can
  /// be reused by the FlutterError hooks before this widget exists). The
  /// root widget owns the [CrashContextBridge] tying it to RoleCubit state.
  /// Defaults to [NoopCrashReporter] so widget tests don't need to inject
  /// a reporter when they don't care about observability behavior.
  final CrashReporter crashReporter;

  /// Optional override — tests inject a [FakePushTransport] here so they can
  /// drive the handler without a real FCM/APNs connection. When supplied it is
  /// used VERBATIM: the Firebase-init gate and the upgrade path below are
  /// skipped entirely, so a test-injected transport is never replaced.
  final PushTransport? pushTransport;

  /// FIX-1 (init ordering) test seam. Resolves once Firebase is ready. The push
  /// chain awaits this BEFORE building the real [FirebaseMessagingTransport], so
  /// the transport (which reaches `FirebaseMessaging.instance` → `Firebase.app()`)
  /// can never run against an uninitialized core and silently degrade to the
  /// fake. Production leaves this null and uses [_defaultFirebaseInitializer],
  /// which no-ops when Firebase is already up (the deferred bootstrap init) and
  /// otherwise initializes it. Only exercised when [pushTransport] is null.
  final Future<void> Function()? firebaseInitializer;

  /// FIX-1 test seam. Builds (and initializes) the real push transport AFTER
  /// [firebaseInitializer] resolves. Production leaves this null and uses
  /// [_defaultFcmTransportBuilder]. A throw here degrades to [FakePushTransport]
  /// (a genuine bridge failure must never crash the app). Only exercised when
  /// [pushTransport] is null.
  final Future<PushTransport> Function()? fcmTransportBuilder;

  /// Optional override for the device-token registrar. When supplied it is wired
  /// through [PushNotificationHandler.onToken] so the boot/refresh FCM token is
  /// forwarded to `PUT /api/PushNotification/register` for ANY transport (the
  /// iter7 device-registration seam). Production leaves this null and, for the
  /// real FCM transport, starts the polling [DeviceTokenRegistrar] instead so
  /// registration fires AFTER login.
  final PushDeviceRegistrar? pushDeviceRegistrar;

  /// Optional override for the biometric prompt (T-mobile-005). Production
  /// defers to [UnavailableBiometricGateway] until the `local_auth` plugin
  /// ticket lands; tests can inject a scripted fake to drive the lock screen
  /// deterministically.
  final BiometricGateway? biometricGateway;

  /// Optional override for the session/JWT router gate (FR-P0-3). Production
  /// builds a real [SessionCubit] over [AuthTokenStore] (secure keystore) when
  /// this is null; widget tests inject a scripted [SessionGate] (e.g.
  /// [AlwaysAuthenticatedSessionGate]) so they don't need a keystore. When an
  /// override is supplied it is NOT owned by this widget (no dispose).
  final SessionGate? sessionGate;

  @override
  State<JeebApp> createState() => _JeebAppState();
}

class _JeebAppState extends State<JeebApp> with WidgetsBindingObserver {
  late final OnboardingCubit _onboarding =
      OnboardingCubit(prefs: widget.preferences);
  late final RoleCubit _role = RoleCubit(
    prefs: widget.preferences,
    initialRole: _devSeamRole,
  );

  /// BUG-1 / CORE UX RULE: the user's resolved `available_roles` from the
  /// gateway Auth/Capabilities surface (getMe). The additive shell watches this
  /// to (a) light up the jeeber tab bodies vs their empty states and (b) LAND a
  /// dual-role jeeber on the Jeeber surface instead of the client surface.
  /// Empty until the first [RoleSync.sync] resolves, so a plain client never
  /// flashes jeeber content.
  late final RoleAvailabilityCubit _roleAvailability = RoleAvailabilityCubit();

  /// BUG-1: login→capability sync. Reads getMe and publishes `available_roles`
  /// (and the server `active_role`) to [_roleAvailability] / [_role]. Resolves
  /// the getMe repo over the shared Dio (no DI edit) and is a safe no-op in
  /// widget tests / when unauthenticated. Skipped while a dev seam pins the
  /// role for a capture build (the seam owns the surface then).
  late final RoleSync _roleSync = RoleSync(
    roleCubit: _role,
    availabilityCubit: _roleAvailability,
  );

  /// Debug-only: the `jeeb.feed` dev seam captures the deliveryman (jeeber)
  /// feed, so force the jeeber role when it's set. `null` in release and when
  /// the seam isn't driving the feed, preserving the persisted role.
  UserRole? get _devSeamRole =>
      kDebugMode && DevSeam.current.hasFeed ? UserRole.jeeber : null;

  /// True when a dev seam is pinning the role for a deterministic capture; the
  /// getMe capability-sync must NOT fight it then.
  bool get _seamPinsRole => _devSeamRole != null;
  late final RoleEligibilityCubit _roleEligibility = RoleEligibilityCubit();
  // Mirrors RoleCubit/OnboardingCubit — built directly from the prefs the
  // bootstrap handed us so widget tests don't need to configure GetIt. The
  // production DI graph still wires the same impls behind these interfaces;
  // this constructor just doesn't depend on it being initialized.
  late final BiometricLockCubit _biometricLock = BiometricLockCubit(
    preference:
        BiometricPreferenceRepositoryImpl(prefs: widget.preferences),
    // This is the app-level cubit the router gate watches AND the one the
    // `/lock` screen consumes (BlocProvider.value) — the SAME instance whose
    // authenticate() must succeed for JM-005 to release to the shell. RC-3: in
    // DEBUG (no test override) wire [DevBiometricGateway] so the challenge
    // resolves `true`. A test-injected `biometricGateway` always wins; release
    // keeps the production [UnavailableBiometricGateway] (kDebugMode const false
    // → dev path tree-shaken).
    gateway: widget.biometricGateway ??
        (kDebugMode
            ? const DevBiometricGateway()
            : const UnavailableBiometricGateway()),
    pinRepository: SharedPrefsPinRepository(prefs: widget.preferences),
  )..evaluate();

  /// FR-P0-3: the production session/JWT gate. Built over a real
  /// [AuthTokenStore] (secure keystore) unless a test injects a [sessionGate].
  /// We hold a reference to the [SessionCubit] only when WE created it, so
  /// dispose closes exactly what we own. The router reads it as a [SessionGate];
  /// [_evaluateSession] kicks the first keystore read after first frame.
  late final SessionCubit? _ownedSession =
      widget.sessionGate == null ? SessionCubit(tokenStore: AuthTokenStore()) : null;
  late final SessionGate _session = widget.sessionGate ?? _ownedSession!;

  /// JM-006 / D5 account-status gate. In DEBUG we wire a [SeededAccountStatusGate]
  /// so the `jeeb.seam.session=suspended` harness routes to `/account-status`
  /// (62_SEAM_HARNESS.md); the flag was written during bootstrap, before this is
  /// read. In release we keep the inert default ([AlwaysActiveAccountStatusGate])
  /// — the real JM-006 account-status cubit (GET /users/:id) supersedes this when
  /// it lands. Inert (`isBlocked == false`) for every non-suspended seed and for
  /// un-seeded launches, so it never affects normal routing.
  late final AccountStatusGate _accountStatus = kDebugMode
      ? SeededAccountStatusGate(widget.preferences)
      : const AlwaysActiveAccountStatusGate();
  late final GoRouter _router = AppRouter.create(
    onboarding: _onboarding,
    biometricLock: _biometricLock,
    session: _session,
    accountStatus: _accountStatus,
  );
  // BadgeCountCubit is cheap (in-memory Cubit<int>) and is read by the
  // MultiBlocProvider on first build, so it stays eager.
  late final BadgeCountCubit _badgeCount = BadgeCountCubit();
  late final CrashContextBridge _crashContext = CrashContextBridge(
    reporter: widget.crashReporter,
    roleCubit: _role,
  );

  // Deferred — assigned by [_initPushChain] after first frame paints.
  // The transport itself isn't held here: `PushNotificationHandler.dispose`
  // already cascades into `transport.dispose()`.
  PushNotificationHandler? _pushHandler;
  NotificationDispatcher? _dispatcher;
  DeviceTokenRegistrar? _deviceRegistrar;

  /// BUG-1: subscription to the owned [SessionCubit] so a successful login
  /// (OTP verify / super-login calls `session.refresh()`, transitioning the
  /// session to authenticated) re-fires [RoleSync.sync] IMMEDIATELY — without
  /// waiting for a background/foreground cycle. Only created when WE own the
  /// session (a test-injected bare [SessionGate] is not a cubit and has no
  /// stream); null otherwise. Closed in [dispose].
  StreamSubscription<SessionState>? _sessionSub;

  /// Re-entrancy guard for the empty-stack recovery below: a stack-REPLACING
  /// AppBar back that pops go_router's lone page empties the Navigator, so
  /// `MaterialApp.router` hands its `builder` a NULL child. Rather than render
  /// the resulting blank/black surface (`SizedBox.shrink()` — unrecoverable
  /// without a cold restart), we bounce back to `/` on the next frame. Guarded
  /// so the recovery `go('/')` is scheduled once, not every rebuild while the
  /// null-child frame is on screen.
  bool _recoveringEmptyStack = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // FR-P0-3: evaluate the session AFTER first frame. The cubit starts in the
    // `unknown` phase (router gate is a no-op) so we never flash `/register`
    // during the keystore read; once this resolves, an onboarded-but-tokenless
    // user is redirected to login via `refreshListenable`.
    _ownedSession?.refresh();
    // BUG-1: the OTP-verify / super-login path calls `session.refresh()`,
    // transitioning the SessionCubit to `authenticated` — listen for that
    // transition and (re-)resolve capabilities so the shell lands a jeeber on
    // the Jeeber surface right after the first login, no background cycle.
    _wireSessionRoleSync();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // FIX-1: the push chain is async — it awaits the Firebase-init gate before
      // building the real transport. Fire-and-forget; failures degrade to the
      // in-memory fake inside [_initPushChainAsync] and never crash cold start.
      unawaited(_initPushChainAsync());
      // BUG-1: resolve `available_roles` from getMe after the first frame
      // paints (never blocks cold start). A returning dual-role jeeber lands on
      // the Jeeber surface; a plain client stays on the client surface.
      _syncRole();
    });
  }

  /// BUG-1: reconcile local capability state with the gateway. No-op while a
  /// dev seam pins the role for a capture build.
  void _syncRole() {
    if (_seamPinsRole) return;
    unawaited(_roleSync.sync());
  }

  /// BUG-1: re-run [_syncRole] on every transition INTO the authenticated
  /// session state — the login-completion trigger. We only listen when WE own
  /// the session (a test-injected bare [SessionGate] exposes no stream). The
  /// first authenticated emission also re-syncs, which is harmless:
  /// [RoleSync.sync] is idempotent and now runs post-auth (getMe succeeds).
  void _wireSessionRoleSync() {
    final session = _ownedSession;
    if (session == null) return;
    _sessionSub = session.stream.listen((state) {
      if (state.isAuthenticated) {
        _syncRole();
        // run-15: the device-registration poll started at cold start can expire
        // before the user logs in interactively. Re-arm registration on the
        // login transition so `PUT /api/PushNotification/register` still fires.
        // Idempotent — a no-op once already registered.
        final registrar = _deviceRegistrar;
        if (registrar != null) unawaited(registrar.notifyLogin());
      }
    });
  }

  /// BUG-1: re-resolve capabilities on app-resume so a role granted on another
  /// device (or after a backgrounded session) reflects when the app returns to
  /// the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _syncRole();
  }

  /// FIX-1 — Firebase-vs-push init ordering.
  ///
  /// The race this fixes: `Firebase.initializeApp()` runs in the DEFERRED
  /// (post-first-frame) bootstrap, and the push chain ALSO runs post-first-frame.
  /// The old synchronous chain checked `Firebase.apps.isEmpty` and, if Firebase
  /// had not finished initializing yet, permanently degraded to
  /// [FakePushTransport] — no real transport, no FCM token, no registration.
  ///
  /// Now the chain AWAITS the Firebase-init gate ([firebaseInitializer]) BEFORE
  /// building the real transport ([fcmTransportBuilder]). An injected
  /// [pushTransport] short-circuits both (the test seam is used verbatim). A
  /// genuine build failure still degrades to the fake so the app never crashes.
  Future<void> _initPushChainAsync() async {
    if (!mounted) return;
    final override = widget.pushTransport;
    final PushTransport transport;
    if (override != null) {
      transport = override;
    } else {
      PushTransport built;
      try {
        await (widget.firebaseInitializer ?? _defaultFirebaseInitializer)();
        built = await (widget.fcmTransportBuilder ?? _defaultFcmTransportBuilder)();
      } catch (error) {
        // No Firebase config, or a real FCM/bridge failure. Degrade to the
        // in-memory fake so the banner UI still works and cold start survives.
        if (kDebugMode) {
          debugPrint('[push] FCM transport unavailable; using fake: $error');
        }
        built = FakePushTransport();
      }
      transport = built;
    }
    // A late unmount (dispose raced the await) must not leak the transport.
    if (!mounted) {
      unawaited(transport.dispose());
      return;
    }

    // PUSH-WIRING / registration:
    // - A test-injected [pushDeviceRegistrar] is wired through the handler's
    //   onToken hook so the boot/refresh token is forwarded for ANY transport.
    // - Otherwise, for the REAL FCM transport, start the polling
    //   [DeviceTokenRegistrar] so `PUT /api/PushNotification/register` fires
    //   AFTER login (it polls the keystore for a userId). A fake transport in
    //   tests has no real token, so no registration is attempted.
    final injectedRegistrar = widget.pushDeviceRegistrar;
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: _badgeCount,
      onToken: injectedRegistrar?.register,
      // Publish a status-change signal on delivery pushes so the customer home
      // / tracking surfaces refetch promptly (sprint-009 live refresh).
      refreshSignals: sl.isRegistered<PushRefreshSignals>()
          ? sl<PushRefreshSignals>()
          : null,
      // Publish an offer-lifecycle signal on offer_accepted/offer_lost pushes so
      // the jeeber's pending-offers list flips the row + re-pulls (sprint-009).
      offerLifecycleSignals: sl.isRegistered<OfferLifecycleSignals>()
          ? sl<OfferLifecycleSignals>()
          : null,
    );
    if (injectedRegistrar == null && transport is FirebaseMessagingTransport) {
      final registrar = DeviceTokenRegistrar(
        dio: sl<Dio>(),
        tokenStore: sl<AuthTokenStore>(),
        transport: transport,
        prefs: widget.preferences,
      );
      unawaited(registrar.start());
      _deviceRegistrar = registrar;
    }
    final dispatcher = NotificationDispatcher(
      handler: handler,
      router: _router,
      // Cold-start: route the tap that launched the app from a terminated
      // state (the jeeber's chat-push entry point) once the router is built.
      initialMessage: transport.initialMessage(),
    );
    setState(() {
      _pushHandler = handler;
      _dispatcher = dispatcher;
    });
  }

  /// Default Firebase-init gate. No-op when Firebase is already up (the deferred
  /// bootstrap's `Firebase.initializeApp()` won the race); otherwise initializes
  /// the default app itself so the real transport can be built. Swallows the
  /// `duplicate-app` race with the concurrent bootstrap init. In a build with no
  /// `google-services.json` (or a plain widget test) `initializeApp` throws and
  /// the caller degrades to the fake.
  static Future<void> _defaultFirebaseInitializer() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') return;
      rethrow;
    }
  }

  /// Default real-transport builder. `initialize()` wires the background
  /// handler, the Android channel, and the foreground listeners; the handler
  /// subscribes to the transport's broadcast streams immediately after, so
  /// ordering is safe.
  static Future<PushTransport> _defaultFcmTransportBuilder() async {
    final transport = FirebaseMessagingTransport();
    await transport.initialize();
    return transport;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _crashContext.dispose();
    _deviceRegistrar?.dispose();
    _dispatcher?.dispose();
    _pushHandler?.dispose();
    _badgeCount.close();
    _biometricLock.close();
    _roleEligibility.close();
    _roleAvailability.close();
    _role.close();
    _onboarding.close();
    _sessionSub?.cancel();
    _ownedSession?.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit(prefs: widget.preferences)),
        BlocProvider.value(value: _role),
        BlocProvider.value(value: _roleAvailability),
        BlocProvider.value(value: _roleEligibility),
        BlocProvider.value(value: _onboarding),
        BlocProvider.value(value: _biometricLock),
        BlocProvider.value(value: _badgeCount),
        // FR-P0-3 (defect DEF-1): expose the production SessionCubit to the
        // tree so a successful login (OTP verify / super-login) can call
        // `refresh()` — that emit drives `refreshListenable` and re-runs the
        // router redirect, promoting `/` to Home instead of bouncing back to
        // `/register`. Only provided when WE own the cubit; when a test injects
        // a bare SessionGate there is no cubit to provide, and the login
        // screens read it as `SessionCubit?` (null → no-op).
        if (_ownedSession != null) BlocProvider.value(value: _ownedSession),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          // OmdsColorTokensProvider exposes `context.omdsColorTokens` to the
          // entire widget tree below MaterialApp. We use the default token
          // set — Jeeb has no brand-specific overrides for grey-scale,
          // shimmer, or semantic success/warning/info today. If that
          // changes, override here, not per-feature.
          return OmdsColorTokensProvider(
            tokens: const OmdsColorTokens(),
            child: MaterialApp.router(
              title: 'Jeeb',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ThemeMode.system,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: [
                widget.localizationsDelegateOverride ??
                    AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: _router,
              builder: (context, child) {
                // Central blank-surface safety net (complements the per-route
                // [RootAwareBackScope] which guards the SYSTEM back gesture).
                // An unguarded AppBar back arrow on a `go`-replaced screen can
                // still pop go_router's lone page and empty the Navigator, in
                // which case `child` is NULL. Recover to `/` (the first-run
                // gate then re-routes for the auth state) instead of leaving a
                // dead blank surface. Scheduled once via the re-entrancy guard.
                if (child == null) {
                  if (!_recoveringEmptyStack) {
                    _recoveringEmptyStack = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _router.go('/');
                      _recoveringEmptyStack = false;
                    });
                  }
                  return const SizedBox.shrink();
                }
                _recoveringEmptyStack = false;
                final content = child;
                final handler = _pushHandler;
                // Until the push chain finishes initializing post-first-frame,
                // render the router content directly — no banner host. Once
                // [_initPushChain] runs, this rebuilds with the banner overlay.
                final wrapped = handler == null
                    ? content
                    : PushBannerHost(
                        handler: handler,
                        onBannerTap: (message) {
                          final path = deepLinkForMessage(message);
                          if (path != null) _router.go(path);
                        },
                        child: content,
                      );
                return jeebA11yBuilder(context, wrapped);
              },
            ),
          );
        },
      ),
    );
  }
}
