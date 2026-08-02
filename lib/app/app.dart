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
import '../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../features/biometric_auth/data/dev_biometric_gateway.dart';
import '../features/biometric_auth/data/local_auth_biometric_gateway.dart';
import '../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../features/biometric_auth/domain/biometric_gateway.dart';
import '../features/settings/data/repositories/biometric_preference_repository_impl.dart';
import '../l10n/app_localizations.dart';

import '../core/previews/jeeb_preview.dart';

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

  final LocalizationsDelegate<AppLocalizations>? localizationsDelegateOverride;

  final CrashReporter crashReporter;

  final PushTransport? pushTransport;

  /// FIX-1: awaited before building real transport (Firebase-vs-push init ordering).
  final Future<void> Function()? firebaseInitializer;

  final Future<PushTransport> Function()? fcmTransportBuilder;

  final PushDeviceRegistrar? pushDeviceRegistrar;

  final BiometricGateway? biometricGateway;

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

  late final RoleAvailabilityCubit _roleAvailability = RoleAvailabilityCubit();

  late final RoleSync _roleSync = RoleSync(
    roleCubit: _role,
    availabilityCubit: _roleAvailability,
  );

  UserRole? get _devSeamRole =>
      kDebugMode && DevSeam.current.hasFeed ? UserRole.jeeber : null;

  bool get _seamPinsRole => _devSeamRole != null;
  late final RoleEligibilityCubit _roleEligibility = RoleEligibilityCubit();
  late final BiometricLockCubit _biometricLock = BiometricLockCubit(
    preference:
        BiometricPreferenceRepositoryImpl(prefs: widget.preferences),
    gateway: widget.biometricGateway ??
        (kDebugMode
            ? const DevBiometricGateway()
            : LocalAuthBiometricGateway()),
    pinRepository: SharedPrefsPinRepository(prefs: widget.preferences),
  )..evaluate();

  late final SessionCubit? _ownedSession =
      widget.sessionGate == null ? SessionCubit(tokenStore: AuthTokenStore()) : null;
  late final SessionGate _session = widget.sessionGate ?? _ownedSession!;

  late final LocaleCubit _locale = LocaleCubit(
    prefs: widget.preferences,
    remote: sl.isRegistered<LanguagePreferenceRepository>()
        ? sl<LanguagePreferenceRepository>()
        : null,
  );

  late final AccountStatusGate _accountStatus = kDebugMode
      ? SeededAccountStatusGate(widget.preferences)
      : const AlwaysActiveAccountStatusGate();
  late final GoRouter _router = AppRouter.create(
    onboarding: _onboarding,
    biometricLock: _biometricLock,
    session: _session,
    accountStatus: _accountStatus,
  );
  late final BadgeCountCubit _badgeCount = BadgeCountCubit(
    inbox: sl.isRegistered<LocalPushInbox>() ? sl<LocalPushInbox>() : null,
  );
  late final CrashContextBridge _crashContext = CrashContextBridge(
    reporter: widget.crashReporter,
    roleCubit: _role,
  );

  PushNotificationHandler? _pushHandler;
  NotificationDispatcher? _dispatcher;
  DeviceTokenRegistrar? _deviceRegistrar;

  StreamSubscription<SessionState>? _sessionSub;

  StreamSubscription<void>? _resumeSub;

  bool _recoveringEmptyStack = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownedSession?.refresh();
    _wireSessionRoleSync();
    AppResumeSignals.instance.install();
    _wireAppResumeRefetch();
    _bindNetworkReachability();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      /// FIX-1: push chain is async, fails soft to fake.
      unawaited(_initPushChainAsync());
      _syncRole();
      unawaited(_badgeCount.hydrate());
    });
  }

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

  void _syncRole() {
    if (_seamPinsRole) return;
    unawaited(_roleSync.sync());
  }

  void _wireSessionRoleSync() {
    final session = _ownedSession;
    if (session == null) return;
    _sessionSub = session.stream.listen((state) {
      if (state.isAuthenticated) {
        _syncRole();
        unawaited(_locale.syncFromServer());
        final registrar = _deviceRegistrar;
        if (registrar != null) unawaited(registrar.notifyLogin());
      } else if (state.isUnauthenticated) {
        _deviceRegistrar?.notifySignedOut();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(Diag.flushPersistent());
    }
  }

  void _wireAppResumeRefetch() {
    _resumeSub = AppResumeSignals.instance.stream.listen((_) {
      _syncRole();
      unawaited(_badgeCount.hydrate());
    });
  }

  /// FIX-1: Firebase-vs-push init ordering.
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
        if (kDebugMode) {
          debugPrint('[push] FCM transport unavailable; using fake: $error');
        }
        built = FakePushTransport();
      }
      transport = built;
    }
    if (!mounted) {
      unawaited(transport.dispose());
      return;
    }

    final injectedRegistrar = widget.pushDeviceRegistrar;
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: _badgeCount,
      onToken: injectedRegistrar?.register,
      refreshSignals: sl.isRegistered<PushRefreshSignals>()
          ? sl<PushRefreshSignals>()
          : null,
      offerLifecycleSignals: sl.isRegistered<OfferLifecycleSignals>()
          ? sl<OfferLifecycleSignals>()
          : null,
      localInbox: sl.isRegistered<LocalPushInbox>()
          ? sl<LocalPushInbox>()
          : null,
      localRoles: () {
        final available = _roleAvailability.state.roles.toSet();
        return available.isNotEmpty
            ? available
            : <String>{_role.state.storageKey};
      },
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
      initialMessage: transport.initialMessage(),
      roleResolver: () => _role.state,
    );
    setState(() {
      _pushHandler = handler;
      _dispatcher = dispatcher;
    });
  }

  static Future<void> _defaultFirebaseInitializer() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') return;
      rethrow;
    }
  }

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
    _resumeSub?.cancel();
    _ownedSession?.close();
    _locale.close();
    _router.dispose();
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
        if (_ownedSession != null) BlocProvider.value(value: _ownedSession),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
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
                final wrapped = handler == null
                    ? content
                    : PushBannerHost(
                        handler: handler,
                        onBannerTap: (message) {
                          final path =
                              deepLinkForMessage(message, role: _role.state);
                          if (path != null) _router.go(path);
                        },
                        child: content,
                      );
                final routed = jeebA11yBuilder(context, wrapped);
                final observed = kObsCompiledIn
                    ? ObsOverlayHost(child: routed)
                    : routed;
                return kDevAffordancesAllowed
                    ? GestureLogListener(child: observed)
                    : observed;
              },
            ),
          );
        },
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// This widget owns the whole viewport, so the canvas box is a phone frame:
/// 390×844 is the iPhone 14 / Galaxy S22 logical size the screen goldens use.
const Size _jeebAppPreviewBox = Size(390, 844);

/// Preview-only override for [JeebApp.localizationsDelegateOverride].
/// Left `null` in the canvas, where the production [AppLocalizations.delegate]
LocalizationsDelegate<AppLocalizations>? jeebAppPreviewLocalizations;

/// The key [LocaleCubit] reads its persisted language from.
/// Duplicated as a literal because the cubit keeps it private. It is asserted
const String _jeebAppLocalePrefKey = 'app.locale.languageCode';

/// A gate that reports "evaluation has RUN and there is no token".
/// Not the same as the cold-start `unknown` phase, which
/// [AlwaysAuthenticatedSessionGate] stands in for above: `isUnauthenticated`
class _JeebAppSignedOutSessionGate implements SessionGate {
  const _JeebAppSignedOutSessionGate();

  @override
  bool get isUnauthenticated => true;
}

/// A device whose biometric sensor is enrolled and always says yes.
/// Injected so the lock preview is deterministic: the debug default
/// ([DevBiometricGateway]) and the release default ([LocalAuthBiometricGateway])
class _JeebAppEnrolledBiometricGateway implements BiometricGateway {
  const _JeebAppEnrolledBiometricGateway();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({required String reason}) async => true;
}

Widget _jeebAppHosted({
  Map<String, Object> seed = const <String, Object>{},
  SessionGate session = const AlwaysAuthenticatedSessionGate(),
  BiometricGateway biometrics = const UnavailableBiometricGateway(),
}) {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(seed);
  return FutureBuilder<SharedPreferences>(
    future: SharedPreferences.getInstance(),
    builder: (BuildContext context, AsyncSnapshot<SharedPreferences> snapshot) {
      final SharedPreferences? prefs = snapshot.data;
      if (prefs == null) return const SizedBox.shrink();
      return JeebApp(
        preferences: prefs,
        sessionGate: session,
        biometricGateway: biometrics,
        pushTransport: FakePushTransport(),
        localizationsDelegateOverride: jeebAppPreviewLocalizations,
      );
    },
  );
}

/// Onboarding complete — the seed every state below the first shares.
Map<String, Object> _jeebAppOnboarded([Map<String, Object> extra = const {}]) =>
    <String, Object>{OnboardingCubit.completedKey: true, ...extra};

@JeebPreview(
  group: 'app',
  name: 'First launch · onboarding',
  size: _jeebAppPreviewBox,
)
Widget jeebAppFirstLaunch() =>
    _jeebAppHosted(session: const _JeebAppSignedOutSessionGate());

@JeebPreview(
  group: 'app',
  name: 'Signed in · shell',
  size: _jeebAppPreviewBox,
  matrix: true,
)
Widget jeebAppSignedIn() => _jeebAppHosted(seed: _jeebAppOnboarded());

@JeebPreview(group: 'app', name: 'Biometric lock', size: _jeebAppPreviewBox)
Widget jeebAppBiometricLocked() => _jeebAppHosted(
      seed: _jeebAppOnboarded(<String, Object>{
        BiometricPreferenceRepositoryImpl.kEnabledKey: true,
      }),
      biometrics: const _JeebAppEnrolledBiometricGateway(),
    );

@JeebPreview(
  group: 'app',
  name: 'Account suspended',
  size: _jeebAppPreviewBox,
)
Widget jeebAppAccountSuspended() => _jeebAppHosted(
      seed: _jeebAppOnboarded(<String, Object>{
        SessionSeamBootstrap.kAccountBlockedKey: true,
      }),
    );

@JeebPreview(
  group: 'app',
  name: 'Arabic app language',
  size: _jeebAppPreviewBox,
  matrix: true,
)
Widget jeebAppArabicLanguage() => _jeebAppHosted(
      seed: _jeebAppOnboarded(<String, Object>{_jeebAppLocalePrefKey: 'ar'}),
    );
