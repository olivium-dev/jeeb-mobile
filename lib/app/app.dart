import 'dart:async';

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
import '../core/notifications/application/notification_dispatcher.dart';
import '../core/notifications/application/push_notification_handler.dart';
import '../core/notifications/data/firebase_messaging_transport.dart';
import '../core/notifications/data/push_device_registrar.dart';
import '../core/notifications/data/push_transport.dart';
import '../core/notifications/domain/notification_message.dart';
import '../core/di/injection_container.dart';
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
  /// drive the handler without a real FCM/APNs connection. In prod this is
  /// null and we fall back to the in-process fake until the native bridge
  /// lands (separate ticket).
  final PushTransport? pushTransport;

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

  /// DEFECT-C: published `available_roles` from getMe — gates the in-app role
  /// toggle + driver surface (empty until the first [RoleSync.sync] resolves,
  /// so single-role clients never flash a toggle).
  late final RoleAvailabilityCubit _roleAvailability = RoleAvailabilityCubit();

  /// DEFECT-C: login→role sync. Reads getMe and reconciles [_role] /
  /// [_roleAvailability] with the server's `active_role` + `available_roles`.
  /// Self-resolves the getMe repo over the shared Dio (no DI edit). Skipped
  /// when a dev seam is forcing the role for a capture build (the seam owns the
  /// surface in that case).
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
  /// getMe role-sync must NOT fight it then.
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

  /// DEFECT-C2: subscription to the owned [SessionCubit] so a successful login
  /// (OTP verify / super-login calls `session.refresh()`, which transitions the
  /// session to authenticated) re-fires [RoleSync.sync] IMMEDIATELY — without
  /// waiting for a background/foreground cycle. Only created when WE own the
  /// session (a test-injected bare [SessionGate] is not a cubit and has no
  /// stream); null otherwise. Closed in [dispose].
  StreamSubscription<SessionState>? _sessionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // FR-P0-3: evaluate the session AFTER first frame. The cubit starts in the
    // `unknown` phase (router gate is a no-op) so we never flash `/register`
    // during the keystore read; once this resolves, an onboarded-but-tokenless
    // user is redirected to login via `refreshListenable`.
    _ownedSession?.refresh();
    // DEFECT-C2: cold-start role-sync runs pre-auth (getMe 401s) and resume only
    // re-fires on background/foreground; neither fires on login completion. The
    // OTP-verify / super-login path calls `session.refresh()`, transitioning the
    // SessionCubit to `authenticated` — listen for that transition and re-sync
    // the role so the toggle appears + the shell lands on the server's active
    // role right after the first login, no background/foreground needed.
    _wireSessionRoleSync();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initPushChain();
      // DEFECT-C: sync the active role + available_roles from getMe after the
      // first frame paints (never blocks cold start). A returning dual-role
      // user is flipped onto their server-side active surface; a single-role
      // client stays on client with no toggle shown.
      _syncRole();
    });
  }

  /// DEFECT-C: reconcile local role state with the server. No-op while a dev
  /// seam pins the role for a capture build.
  void _syncRole() {
    if (_seamPinsRole) return;
    unawaited(_roleSync.sync());
  }

  /// DEFECT-C2: re-run [_syncRole] on every transition INTO the authenticated
  /// session state. This is the login-completion trigger DEFECT-C was missing:
  /// the cold-start sync fires pre-auth (getMe 401s) and resume only fires on
  /// background/foreground, so before this the role toggle stayed hidden and the
  /// shell sat on the `client` default until the user backgrounded the app once.
  ///
  /// We only listen when WE own the session — a test-injected bare [SessionGate]
  /// is not a [SessionCubit] and exposes no stream. The first authenticated
  /// emission (e.g. an already-logged-in cold start) also re-syncs, which is
  /// harmless: [RoleSync.sync] is idempotent and now runs post-auth (getMe
  /// succeeds), so it strictly improves on the pre-auth cold-start attempt. All
  /// DEFECT-C fail-safes live in [RoleSync.sync] and the `_seamPinsRole` guard
  /// in [_syncRole] is preserved.
  void _wireSessionRoleSync() {
    final session = _ownedSession;
    if (session == null) return;
    _sessionSub = session.stream.listen((state) {
      if (state.isAuthenticated) _syncRole();
    });
  }

  /// DEFECT-C: re-sync the role on app-resume so a role switched on another
  /// device (or after a backgrounded session) reflects when the app returns to
  /// the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _syncRole();
  }

  void _initPushChain() {
    if (!mounted) return;
    unawaited(_initPushChainAsync());
  }

  /// PUSH-FIX (iter6): wire the REAL FCM transport in production.
  ///
  /// Before this, the chain always fell back to [FakePushTransport] (the real
  /// [FirebaseMessagingTransport] was never instantiated and `initialize()`
  /// was never called), so no FCM token, channel, or background handler ever
  /// existed and no push could land. We now:
  ///   1. build [FirebaseMessagingTransport] (unless a test injected one),
  ///   2. `await initialize()` — registers the background handler, creates the
  ///      Android channel, hooks the foreground/onMessageOpenedApp listeners,
  ///   3. register the FCM token with jeeb-gateway via [PushDeviceRegistrar]
  ///      (on bootstrap + on every token refresh), and
  ///   4. route the cold-start [initialMessage] tap through the dispatcher.
  /// Any failure here (e.g. Firebase not configured on a dev build) degrades to
  /// the in-process [FakePushTransport] so cold start is never broken.
  Future<void> _initPushChainAsync() async {
    if (!mounted) return;
    PushTransport transport;
    Future<NotificationMessage?>? initialMessage;
    if (widget.pushTransport != null) {
      transport = widget.pushTransport!;
    } else {
      try {
        final fcm = FirebaseMessagingTransport();
        await fcm.initialize();
        transport = fcm;
        initialMessage = fcm.initialMessage();
      } catch (error) {
        debugPrint('[push] FCM transport init failed; using fake: $error');
        transport = FakePushTransport();
      }
    }
    if (!mounted) {
      await transport.dispose();
      return;
    }

    // The backend device-registrar shares the gateway Dio so the
    // _AuthInterceptor attaches the logged-in user's bearer; the gateway reads
    // the user_id from that JWT. Skipped for the fake transport (tests/dev).
    final registrar = transport is FirebaseMessagingTransport
        ? PushDeviceRegistrar(dio: resolveGatewayDio())
        : null;

    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: _badgeCount,
      onToken: registrar?.register,
    );
    final dispatcher = NotificationDispatcher(
      handler: handler,
      router: _router,
      initialMessage: initialMessage,
    );
    setState(() {
      _pushHandler = handler;
      _dispatcher = dispatcher;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _crashContext.dispose();
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
                final content = child ?? const SizedBox.shrink();
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
