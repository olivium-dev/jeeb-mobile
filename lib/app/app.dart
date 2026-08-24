import 'dart:async';

import 'package:dio/dio.dart';
import 'package:clarity_flutter/clarity_flutter.dart'
    show ClarityConfig, ClarityMask, ClarityWidget, LogLevel;
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
import '../core/analytics/clarity/application/clarity_controller.dart';
import '../core/analytics/clarity/data/microsoft_clarity_adapter.dart';
import '../core/analytics/clarity/data/shared_prefs_clarity_consent_store.dart';
import '../core/config/app_config.dart';
import '../core/dev_flags.dart';
import '../core/dev_seam/dev_seam.dart';
import '../core/dev_seam/session_seam_bootstrap.dart';
import '../core/diagnostics/diag.dart';
import '../core/diagnostics/gesture_log.dart';
import '../core/lifecycle/app_resume_signals.dart';
import '../core/locale/language_preference_repository.dart';
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
import '../core/notifications/domain/local_push_inbox.dart';
import '../core/notifications/domain/notification_deep_link.dart';
import '../core/notifications/domain/push_audience.dart';
import '../core/notifications/presentation/push_banner_host.dart';
import '../core/observability/crash_context_bridge.dart';
import '../core/observability/crash_reporter.dart';
import '../core/observability/session_trace/observability_config.dart';
import '../core/observability/session_trace/presentation/obs_overlay.dart';
import '../core/network/auth_token_store.dart';
import '../core/network/connectivity_reachability_source.dart';
import '../core/network/network_reachability_signals.dart';
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
import '../core/theme/jeeb_midnight_palette.dart';
import '../core/theme/jeeb_omds_tokens.dart';
import '../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../features/biometric_auth/data/dev_biometric_gateway.dart';
import '../features/biometric_auth/data/local_auth_biometric_gateway.dart';
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
/// The single frame `MaterialApp.router` paints while the empty-stack recovery
/// below runs. Page navy: an empty frame reveals the white native iOS window.
const Widget kEmptyStackFrame = ColoredBox(
  color: JeebMidnight.page,
  child: SizedBox.expand(),
);

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
    this.clarityController,
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

  /// Test seam. Production owns a release/config/consent-gated controller.
  final ClarityController? clarityController;

  @override
  State<JeebApp> createState() => _JeebAppState();
}

class _JeebAppState extends State<JeebApp> with WidgetsBindingObserver {
  late final OnboardingCubit _onboarding = OnboardingCubit(
    prefs: widget.preferences,
  );
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
  late final RoleAvailabilityCubit _roleAvailability = RoleAvailabilityCubit(
    const RoleAvailability(),
    widget.preferences,
  );

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
    preference: BiometricPreferenceRepositoryImpl(prefs: widget.preferences),
    // This is the app-level cubit the router gate watches AND the one the
    // `/lock` screen consumes (BlocProvider.value) — the SAME instance whose
    // authenticate() must succeed for JM-005 to release to the shell. RC-3: in
    // DEBUG (no test override) wire [DevBiometricGateway] so the challenge
    // resolves `true` on the emulator/CI seam. A test-injected `biometricGateway`
    // always wins. JEBV4-213 / E18: RELEASE now wires the real
    // [LocalAuthBiometricGateway] (OS biometric dialog via `local_auth`, with a
    // device-credential PIN/password fallback), replacing the inert
    // [UnavailableBiometricGateway]. kDebugMode is a const false in release, so
    // the DevBiometricGateway branch is tree-shaken out.
    gateway:
        widget.biometricGateway ??
        (kDebugMode
            ? const DevBiometricGateway()
            : LocalAuthBiometricGateway()),
    pinRepository: SharedPrefsPinRepository(prefs: widget.preferences),
  )..evaluate();

  /// FR-P0-3: the production session/JWT gate. Built over a real
  /// [AuthTokenStore] (secure keystore) unless a test injects a [sessionGate].
  /// We hold a reference to the [SessionCubit] only when WE created it, so
  /// dispose closes exactly what we own. The router reads it as a [SessionGate];
  /// [_evaluateSession] kicks the first keystore read after first frame.
  late final SessionCubit? _ownedSession = widget.sessionGate == null
      ? SessionCubit(tokenStore: AuthTokenStore())
      : null;
  late final SessionGate _session = widget.sessionGate ?? _ownedSession!;
  late final ClarityController _clarity =
      widget.clarityController ??
      ClarityController(
        available: AppConfig.clarityAvailable,
        consentStore: SharedPrefsClarityConsentStore(widget.preferences),
        analytics: const MicrosoftClarityAdapter(
          projectId: AppConfig.clarityProjectId,
        ),
      );
  bool get _ownsClarity => widget.clarityController == null;

  /// JEBV4-205 (E10): the app-language cubit, held as a member so the
  /// authenticated-transition listener can call [LocaleCubit.syncFromServer]
  /// after login. The remote-user-preferences store is resolved optionally from
  /// DI (guarded so widget tests without `configureDependencies` stay local-
  /// only); when present the chosen language is mirrored server-side and
  /// re-hydrated on a fresh install (survives reinstall — the ticket DoD).
  late final LocaleCubit _locale = LocaleCubit(
    prefs: widget.preferences,
    remote: sl.isRegistered<LanguagePreferenceRepository>()
        ? sl<LanguagePreferenceRepository>()
        : null,
  );

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
    clarityScreenReporter: _clarity,
  );
  // BadgeCountCubit is cheap (in-memory Cubit<BadgeCounts>) and is read by
  // the MultiBlocProvider on first build, so it stays eager. G3: rendered by
  // the shell's Dashboard-tab badge (newRequests) and cleared on feed view.
  // Wired to the durable [LocalPushInbox] (when DI is configured) so a
  // `new_request` push handled by the FCM background isolate — which cannot
  // reach this cubit — still surfaces a badge once [BadgeCountCubit.hydrate]
  // runs on cold start / resume. Guarded so widget tests without DI still build.
  late final BadgeCountCubit _badgeCount = BadgeCountCubit(
    inbox: sl.isRegistered<LocalPushInbox>() ? sl<LocalPushInbox>() : null,
  );
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

  /// D3: bounded retries for the FCM transport build (see [_initPushChainAsync]).
  static const int _pushTransportMaxAttempts = 4;
  static const Duration _pushTransportRetryDelay = Duration(seconds: 2);

  /// BUG-1: subscription to the owned [SessionCubit] so a successful login
  /// (OTP verify / super-login calls `session.refresh()`, transitioning the
  /// session to authenticated) re-fires [RoleSync.sync] IMMEDIATELY — without
  /// waiting for a background/foreground cycle. Only created when WE own the
  /// session (a test-injected bare [SessionGate] is not a cubit and has no
  /// stream); null otherwise. Closed in [dispose].
  StreamSubscription<SessionState>? _sessionSub;

  /// b02 P0: subscription to the ONE coalesced app-resume signal
  /// ([AppResumeSignals]). Replaces the app-level `resumed` branch of
  /// [didChangeAppLifecycleState]. Closed in [dispose].
  StreamSubscription<void>? _resumeSub;

  /// Re-entrancy guard for the empty-stack recovery below: a stack-REPLACING
  /// AppBar back that pops go_router's lone page empties the Navigator, so
  /// `MaterialApp.router` hands its `builder` a NULL child. Rather than sit on
  /// the resulting dataless navy frame (unrecoverable without a cold restart),
  /// we bounce back to `/` on the next frame. Guarded
  /// so the recovery `go('/')` is scheduled once, not every rebuild while the
  /// null-child frame is on screen.
  bool _recoveringEmptyStack = false;
  bool _clarityContextScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // FR-P0-3: evaluate the session AFTER first frame. The cubit starts in the
    // `unknown` phase (router gate is a no-op) so we never flash `/register`
    // during the keystore read; once this resolves, an onboarded-but-tokenless
    // user is redirected to login via `refreshListenable`.
    _ownedSession?.refresh();
    unawaited(_clarity.loadConsent());
    final ownedSession = _ownedSession;
    if (ownedSession == null) {
      _clarity.updateAuthentication(!_session.isUnauthenticated);
    } else if (ownedSession.state.isKnown) {
      _clarity.updateAuthentication(ownedSession.state.isAuthenticated);
    }
    // BUG-1: the OTP-verify / super-login path calls `session.refresh()`,
    // transitioning the SessionCubit to `authenticated` — listen for that
    // transition and (re-)resolve capabilities so the shell lands a jeeber on
    // the Jeeber surface right after the first login, no background cycle.
    _wireSessionRoleSync();
    // b02 P0: install the ONE app-wide resume bus and take the app-level
    // subscription. Installing here (not lazily at the first screen) means the
    // genuine-resume filter sees every lifecycle transition from cold start,
    // so the first background trip is classified correctly.
    AppResumeSignals.instance.install();
    _wireAppResumeRefetch();
    _bindNetworkReachability();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // FIX-1: the push chain is async — it awaits the Firebase-init gate before
      // building the real transport. Fire-and-forget; failures degrade to the
      // in-memory fake inside [_initPushChainAsync] and never crash cold start.
      unawaited(_initPushChainAsync());
      // BUG-1: resolve `available_roles` from getMe after the first frame
      // paints (never blocks cold start). A returning dual-role jeeber lands on
      // the Jeeber surface; a plain client stays on the client surface.
      _syncRole();
      // G3: seed the badge from any `new_request` pushes the FCM background
      // isolate persisted while the app was terminated — so a dismissed push
      // shows a Dashboard-tab badge on cold start, not just an inbox row.
      unawaited(_badgeCount.hydrate());
    });
  }

  /// Bind the app-wide reconnect bus to the real OS connectivity stream.
  ///
  /// Bound HERE, at app start, rather than lazily from the first screen that
  /// wants it: [NetworkReachabilitySignals] only emits an offline→online EDGE,
  /// so it has to have observed the offline state to recognise the reconnect.
  /// A screen that binds on mount would, in the exact scenario this exists for
  /// (open a chat while the network is already down), take its baseline as
  /// "offline" one moment too late — or worse, take a live `[none]` event as
  /// its baseline and treat the reconnect as the first observation.
  ///
  /// Wrapped defensively: a host with no platform channel registered (a bare
  /// widget test, an unsupported desktop target) must degrade to a bus that
  /// never emits, which is exactly the pre-existing behaviour — every consumer
  /// keeps its bounded backoff as the fallback.
  void _bindNetworkReachability() {
    const source = ConnectivityReachabilitySource();
    try {
      NetworkReachabilitySignals.instance.bindSource(
        source.onlineStates(),
        seed: source.currentlyOnline(),
      );
    } catch (error) {
      Diag.event('network_reachability_bind_failed', <String, Object?>{
        'error': '$error',
      });
    }
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
      _clarity.updateAuthentication(state.isAuthenticated);
      if (state.isAuthenticated) {
        _syncRole();
        // JEBV4-205 (E10): re-hydrate the server-persisted language on the
        // login-completion trigger. On a fresh install the local locale cache
        // is empty, so this restores the user's saved language from the
        // remote-user-preferences store (survives reinstall). Best-effort.
        unawaited(_locale.syncFromServer());
        // run-15 + JEBV4-159: re-arm device-token registration on EVERY
        // transition into authenticated — the initial interactive login (the
        // cold-start poll may have already expired), AND every later sign-out→
        // sign-in, super-login account switch, or role switch on this same live
        // process. notifyLogin() now re-registers the CURRENT user's token
        // whenever the identity changed (idempotent per (user, token)), so a
        // switched-in user is never left with zero server-side tokens.
        final registrar = _deviceRegistrar;
        if (registrar != null) unawaited(registrar.notifyLogin());
      } else if (state.isUnauthenticated) {
        // JEBV4-159: on sign-out, clear the registrar's (user, token) dedup so
        // the next login re-registers even as the same user — the logout flow
        // fires DELETE /api/PushNotification/device, removing this install's
        // token row, and without this reset an identical-key re-login would be
        // skipped as a duplicate.
        _deviceRegistrar?.notifySignedOut();
      }
    });
  }

  /// BUG-1: re-resolve capabilities on app-resume so a role granted on another
  /// device (or after a backgrounded session) reflects when the app returns to
  /// the foreground.
  ///
  /// Diag persistence: on pause/detach, flush the buffered `[jeeb-diag]` lines
  /// to the on-device session file so a backgrounded (or subsequently killed)
  /// run loses nothing. Fire-and-forget + fail-soft — flushPersistent never
  /// throws and is a no-op when no sink is installed (release builds).
  /// b02 P0 — the resume work moved to [AppResumeSignals] (see
  /// [_wireAppResumeRefetch]). The `resumed` branch here fired
  /// [RoleSync.sync] → `GET /v1/users/me` on EVERY `resumed` notification and
  /// was the first leg of the measured 60-read storm (seq 57..114). The
  /// pause/detach branch stays on the raw lifecycle: flushing the diag buffer
  /// is exactly the thing that must happen on every trip out, un-coalesced,
  /// because a coalesced flush is a lost journal.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _clarity.resumeFromLifecycle();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _clarity.suspendForLifecycle();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(Diag.flushPersistent());
    }
  }

  /// Subscribe the app-level resume work to the ONE coalesced resume signal.
  void _wireAppResumeRefetch() {
    _resumeSub = AppResumeSignals.instance.stream.listen((_) {
      _syncRole();
      // G3: re-derive the badge from the durable push store so a `new_request`
      // that arrived (and was dismissed) while the app was backgrounded — seen
      // only by the FCM background isolate — surfaces its Dashboard-tab badge
      // the moment the jeeber returns. FeedResumeRefetcher then clears it if the
      // feed is the visible tab.
      unawaited(_badgeCount.hydrate());
      // D3 self-heal: re-assert this device's push row on resume (rate-limited
      // inside the registrar) so a row lost server-side recovers by itself.
      unawaited(_deviceRegistrar?.revalidate() ?? Future<void>.value());
    });
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
      // D3: the plugin channel is not always up on the first post-frame try
      // (`channel-error`), and a single failure used to strand the whole
      // process on the fake — no FCM token, so no device registration at all.
      final injectedSeam =
          widget.firebaseInitializer != null ||
          widget.fcmTransportBuilder != null;
      final attempts = injectedSeam ? 1 : _pushTransportMaxAttempts;
      PushTransport? built;
      for (var i = 0; i < attempts && built == null; i++) {
        if (i > 0) await Future<void>.delayed(_pushTransportRetryDelay);
        if (!mounted) return;
        try {
          await (widget.firebaseInitializer ?? _defaultFirebaseInitializer)();
          built =
              await (widget.fcmTransportBuilder ??
                  _defaultFcmTransportBuilder)();
        } catch (error) {
          // No Firebase config, or a real FCM/bridge failure. Degrade to the
          // in-memory fake so the banner UI still works and cold start survives.
          if (kDebugMode) {
            debugPrint(
              '[push] FCM transport attempt ${i + 1}/$attempts '
              'failed: $error',
            );
          }
        }
      }
      if (built == null && kDebugMode) {
        debugPrint('[push] FCM transport unavailable; using fake');
      }
      transport = built ?? FakePushTransport();
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
      // G3: persist a FOREGROUND new_request durably too, so the inbox row +
      // badge survive an app kill before the jeeber acts (same store the
      // background isolate + badge hydrate use).
      localInbox: sl.isRegistered<LocalPushInbox>()
          ? sl<LocalPushInbox>()
          : null,
      // P1 defence-in-depth: drop a push whose audience_role is not a role
      // this session holds. The set is the server-published available_roles
      // (RoleSync ← getMe) widened by the active role, and EMPTY while that
      // list is unresolved — empty means "roles unknown" and the matcher fails
      // OPEN, so a pre-getMe or degraded-getMe push is never suppressed (D2).
      localRoles: _sessionLocalRoles,
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
      // F5: the dispatcher asks for the LIVE role on every tap (the user can
      // flip roles at runtime), so a jeeber-scoped destination is never handed
      // to a client (403 dead end — FIX-REQUESTS.md:35).
      roleResolver: () => _role.state,
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

  /// Session roles for push-audience gating: the server available_roles, widened
  /// by the active role and EMPTY while unresolved so the matcher fails OPEN.
  Set<String> _sessionLocalRoles() => sessionPushRoles(
    availableRoles: _roleAvailability.state.roles,
    activeRole: _role.state.storageKey,
  );

  /// Default real-transport builder. `initialize()` wires the background
  /// handler, the Android channel, and the foreground listeners; the handler
  /// subscribes to the transport's broadcast streams immediately after, so
  /// ordering is safe.
  Future<PushTransport> _defaultFcmTransportBuilder() async {
    final transport = FirebaseMessagingTransport(
      localRoles: _sessionLocalRoles,
    );
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
    _resumeSub?.cancel();
    _ownedSession?.close();
    _locale.close();
    _router.dispose();
    _clarity.detachContext();
    if (_ownsClarity) _clarity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _locale),
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
      child: ClarityAnalyticsScope(
        controller: _clarity,
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            // omds widgets read `OmdsColorTokens.defaultTokens` (a light set)
            // DIRECTLY, so the theme override alone cannot reach them.
            return OmdsColorTokensProvider(
              tokens: jeebMidnightOmdsTokens,
              child: MaterialApp.router(
                title: 'Jeeb',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.midnight(),
                darkTheme: AppTheme.midnight(),
                themeMode: ThemeMode.dark,
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
                  _scheduleClarityContextAttach(context);
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
                    return const ClarityMask(child: kEmptyStackFrame);
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
                            // F5: same role guard as the dispatcher — a client
                            // must never be handed a jeeber-scoped destination.
                            final path = deepLinkForMessage(
                              message,
                              role: _role.state,
                            );
                            if (path != null) _router.go(path);
                          },
                          child: content,
                        );
                  final routed = jeebA11yBuilder(context, wrapped);
                  // Session-trace observability tool (devtool-only): a floating
                  // bubble/panel overlay so a developer can start/stop tracing,
                  // watch live screen/api/notification/interaction events, and
                  // export the session — WITHOUT touching the routed content
                  // underneath. Additive only (`Stack`s the overlay on top);
                  // `kObsCompiledIn` is compile-time `false` in a production
                  // build, so this line (and `ObsOverlayHost` itself) is
                  // tree-shaken out and `routed` is returned unchanged.
                  final observed = kObsCompiledIn
                      ? ObsOverlayHost(child: routed)
                      : routed;
                  // GESTURE-LOG hook (dev-affordances only): a translucent,
                  // pass-through root Listener that records taps/gestures the
                  // Flutter engine receives — INCLUDING adb/Maestro-injected taps
                  // `getevent` can't see — onto the `[jeeb-diag]` stream, with
                  // Maestro-ready selectors read from the in-engine semantics.
                  // Additive + non-consuming; `kDevAffordancesAllowed` is a
                  // compile-time `false` in production, so this wrap (and
                  // `GestureLogListener` itself) is tree-shaken out and `observed`
                  // is returned byte-identically. Default OFF at runtime.
                  final productUi = kDevAffordancesAllowed
                      ? GestureLogListener(child: observed)
                      : observed;
                  final maskedProduct = ClarityMask(child: productUi);
                  return ListenableBuilder(
                    listenable: _clarity,
                    child: maskedProduct,
                    builder: (context, child) {
                      if (!_clarity.shouldMountSdkWidget) return child!;
                      return ClarityWidget(
                        key: const ValueKey<String>('jeeb-clarity-sdk'),
                        clarityConfig: ClarityConfig(
                          projectId: AppConfig.clarityProjectId,
                          logLevel: LogLevel.None,
                        ),
                        app: child!,
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _scheduleClarityContextAttach(BuildContext context) {
    if (_clarityContextScheduled) return;
    _clarityContextScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      _clarity.attachContext(context);
    });
  }
}
