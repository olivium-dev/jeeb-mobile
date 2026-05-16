import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/accessibility/accessibility.dart';
import '../core/locale/locale_cubit.dart';
import '../core/notifications/application/badge_count_cubit.dart';
import '../core/notifications/application/notification_dispatcher.dart';
import '../core/notifications/application/push_notification_handler.dart';
import '../core/notifications/data/push_transport.dart';
import '../core/notifications/domain/notification_deep_link.dart';
import '../core/notifications/presentation/push_banner_host.dart';
import '../core/observability/crash_context_bridge.dart';
import '../core/observability/crash_reporter.dart';
import '../core/onboarding/onboarding_cubit.dart';
import '../core/role/role_cubit.dart';
import '../core/role/role_eligibility_cubit.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/biometric_auth/application/biometric_lock_cubit.dart';
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
  });

  final SharedPreferences preferences;

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

  @override
  State<JeebApp> createState() => _JeebAppState();
}

class _JeebAppState extends State<JeebApp> {
  late final OnboardingCubit _onboarding =
      OnboardingCubit(prefs: widget.preferences);
  late final RoleCubit _role = RoleCubit(prefs: widget.preferences);
  late final RoleEligibilityCubit _roleEligibility = RoleEligibilityCubit();
  // Mirrors RoleCubit/OnboardingCubit — built directly from the prefs the
  // bootstrap handed us so widget tests don't need to configure GetIt. The
  // production DI graph still wires the same impls behind these interfaces;
  // this constructor just doesn't depend on it being initialized.
  late final BiometricLockCubit _biometricLock = BiometricLockCubit(
    preference:
        BiometricPreferenceRepositoryImpl(prefs: widget.preferences),
    gateway: widget.biometricGateway ?? const UnavailableBiometricGateway(),
    pinRepository: SharedPrefsPinRepository(prefs: widget.preferences),
  )..evaluate();
  late final GoRouter _router = AppRouter.create(
    onboarding: _onboarding,
    biometricLock: _biometricLock,
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

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _initPushChain());
  }

  void _initPushChain() {
    if (!mounted) return;
    final transport = widget.pushTransport ?? FakePushTransport();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: _badgeCount,
    );
    final dispatcher = NotificationDispatcher(
      handler: handler,
      router: _router,
    );
    setState(() {
      _pushHandler = handler;
      _dispatcher = dispatcher;
    });
  }

  @override
  void dispose() {
    _crashContext.dispose();
    _dispatcher?.dispose();
    _pushHandler?.dispose();
    _badgeCount.close();
    _biometricLock.close();
    _roleEligibility.close();
    _role.close();
    _onboarding.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit(prefs: widget.preferences)),
        BlocProvider.value(value: _role),
        BlocProvider.value(value: _roleEligibility),
        BlocProvider.value(value: _onboarding),
        BlocProvider.value(value: _biometricLock),
        BlocProvider.value(value: _badgeCount),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            title: 'Jeeb',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
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
          );
        },
      ),
    );
  }
}
