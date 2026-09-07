// Close-out batch (2026-08-11): pill-nav LABELS follow the ACTIVE ROLE, and
// hardware BACK at the shell root no longer destroys the task on first press.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pill_nav.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _StubEarningsRepository implements EarningsRepository {
  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => const EarningsSummary(
    totalCashEarned: 0,
    feesPaid: 0,
    currency: 'USD',
    deliveryCount: 0,
  );

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => '/tmp/earnings.pdf';
}

class _TerminalProfileAdapter implements HttpClientAdapter {
  const _TerminalProfileAdapter(this.failure);

  final AppFailure failure;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{}',
    switch (failure) {
      ForbiddenFailure() => 403,
      NotFoundFailure() => 404,
      GoneFailure() => 410,
      _ => throw StateError('Unsupported terminal profile test failure'),
    },
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void _registerTerminalProfileFailure(AppFailure failure) {
  sl.registerSingleton<CustomerProfileRepository>(
    _TerminalProfileRepository(failure),
  );
  sl.registerSingleton<Dio>(
    Dio(BaseOptions(baseUrl: 'https://profile.test'))
      ..httpClientAdapter = _TerminalProfileAdapter(failure),
    dispose: (dio) => dio.close(force: true),
  );
}

class _TerminalProfileRepository implements CustomerProfileRepository {
  const _TerminalProfileRepository(this.failure);

  final AppFailure failure;

  @override
  Future<CustomerProfileViewData> fetchProfile() async =>
      throw CustomerProfileRepositoryException.classified(
        CustomerProfileFailure.unknown,
        appFailure: failure,
      );
}

final class _FakeObsSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> close() async {}

  @override
  Future<void> flush() async {}

  @override
  String get sessionFilePath => '/fake/shell-session.jsonl';
}

Widget _harness(SharedPreferences prefs, {required UserRole role}) =>
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LocaleCubit(
            prefs: prefs,
            deviceLocaleProvider: () => const Locale('en'),
          ),
        ),
        BlocProvider(
          create: (_) => RoleCubit(prefs: prefs, initialRole: role),
        ),
        BlocProvider(create: (_) => RoleEligibilityCubit()),
        // Capabilities stay CLIENT-only on purpose: the labels must follow the
        // active role without the live jeeber bodies being mounted.
        BlocProvider(
          create: (_) =>
              RoleAvailabilityCubit(const RoleAvailability(roles: ['client'])),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.midnight(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ShellScreen(),
      ),
    );

/// The real app mounts the shell under `MaterialApp.router` + go_router, which
/// is the only configuration in which the device BACK defect reproduces.
Widget _routerHarness(
  SharedPreferences prefs, {
  required UserRole role,
  Locale locale = const Locale('en'),
  GoRouter? appRouter,
}) {
  final router =
      appRouter ??
      GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: 'shell',
            builder: (_, _) => const ShellScreen(),
          ),
          GoRoute(
            path: '/pushed',
            builder: (_, _) => const Scaffold(body: Text('pushed route')),
          ),
        ],
      );
  addTearDown(router.dispose);
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => const Locale('en'),
        ),
      ),
      BlocProvider(
        create: (_) => RoleCubit(prefs: prefs, initialRole: role),
      ),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
      BlocProvider(
        create: (_) =>
            RoleAvailabilityCubit(const RoleAvailability(roles: ['client'])),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

List<String> _labels(WidgetTester tester) => tester
    .widget<JeebPillNav>(find.byType(JeebPillNav))
    .items
    .map((JeebPillNavItem i) => i.label)
    .toList();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    sl.registerFactory<EarningsRepository>(() => _StubEarningsRepository());
    sl.registerLazySingleton<AvailabilityGateway>(
      InMemoryAvailabilityGateway.new,
    );
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(const []),
    );
  });

  tearDown(() async {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
    await sl.reset();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final failure in const <AppFailure>[
      ForbiddenFailure(reasonCode: 'role_mismatch'),
      NotFoundFailure(),
      GoneFailure(),
    ]) {
      for (final withProfileData in [true, false]) {
        testWidgets(
          'standalone profile ${failure.kind.name} exit retains shell '
          '${locale.languageCode} data=$withProfileData',
          (tester) async {
            _reduceMotion(tester);
            final semantics = tester.ensureSemantics();
            try {
              _registerTerminalProfileFailure(failure);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('app.onboarding.completed', true);
              final onboarding = OnboardingCubit(prefs: prefs);
              final lock = BiometricLockCubit(
                preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
                gateway: const UnavailableBiometricGateway(),
                pinRepository: SharedPrefsPinRepository(prefs: prefs),
              );
              addTearDown(onboarding.close);
              addTearDown(lock.close);
              final router = AppRouter.create(
                onboarding: onboarding,
                biometricLock: lock,
              );
              await tester.pumpWidget(
                _routerHarness(
                  prefs,
                  role: UserRole.client,
                  locale: locale,
                  appRouter: router,
                ),
              );
              await _settle(tester);
              final shellState = tester.state(find.byType(ShellScreen));
              for (var attempt = 0; attempt < 2; attempt++) {
                await tester.tap(
                  find.bySemanticsIdentifier('shell_tab_profile'),
                );
                await _settle(tester);
                expect(
                  tester
                      .widget<JeebPillNav>(find.byType(JeebPillNav))
                      .selectedIndex,
                  4,
                );
                router.pushNamed<void>(
                  'customer-profile',
                  extra: withProfileData
                      ? const CustomerProfileViewData()
                      : null,
                );
                await _settle(tester);
                expect(router.canPop(), isTrue);
                if (withProfileData) {
                  expect(
                    find.bySemanticsIdentifier('customer_profile_load_error'),
                    findsOneWidget,
                  );
                  await tester.tap(
                    find.bySemanticsIdentifier(
                      'customer_profile_load_exit_cta',
                    ),
                  );
                } else {
                  // The debug fixture is seeded, so failures keep its warm UI.
                  final profile = tester.widget<CustomerProfileScreen>(
                    find.byType(CustomerProfileScreen),
                  );
                  expect(profile.onExit, isNotNull);
                  profile.onExit!();
                }
                await _settle(tester);
                expect(router.routeInformationProvider.value.uri.path, '/');
                expect(router.canPop(), isFalse);
                expect(
                  tester.state(find.byType(ShellScreen)),
                  same(shellState),
                );
                expect(
                  tester
                      .widget<JeebPillNav>(find.byType(JeebPillNav))
                      .selectedIndex,
                  0,
                );
                expect(
                  find.bySemanticsIdentifier('customer_profile_load_error'),
                  findsNothing,
                );
                expect(tester.takeException(), isNull);
              }
            } finally {
              semantics.dispose();
            }
          },
        );
      }
      testWidgets(
        'cold standalone profile ${failure.kind.name} exit opens Requests '
        '${locale.languageCode}',
        (tester) async {
          _reduceMotion(tester);
          final semantics = tester.ensureSemantics();
          try {
            _registerTerminalProfileFailure(failure);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('app.onboarding.completed', true);
            final onboarding = OnboardingCubit(prefs: prefs);
            final lock = BiometricLockCubit(
              preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
              gateway: const UnavailableBiometricGateway(),
              pinRepository: SharedPrefsPinRepository(prefs: prefs),
            );
            addTearDown(onboarding.close);
            addTearDown(lock.close);
            final router = AppRouter.create(
              onboarding: onboarding,
              biometricLock: lock,
            );
            router.goNamed(
              'customer-profile',
              extra: const CustomerProfileViewData(),
            );
            await tester.pumpWidget(
              _routerHarness(
                prefs,
                role: UserRole.client,
                locale: locale,
                appRouter: router,
              ),
            );
            await _settle(tester);
            expect(
              router.routeInformationProvider.value.uri.path,
              '/profile/customer',
            );
            expect(router.canPop(), isFalse);
            expect(find.byType(ShellScreen), findsNothing);
            expect(
              find.bySemanticsIdentifier('customer_profile_load_error'),
              findsOneWidget,
            );
            await tester.tap(
              find.bySemanticsIdentifier('customer_profile_load_exit_cta'),
            );
            await _settle(tester);
            expect(router.routeInformationProvider.value.uri.path, '/');
            expect(router.canPop(), isFalse);
            expect(find.byType(ShellScreen), findsOneWidget);
            expect(
              tester
                  .widget<JeebPillNav>(find.byType(JeebPillNav))
                  .selectedIndex,
              0,
            );
            expect(
              find.bySemanticsIdentifier('customer_profile_load_error'),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final failure in const <AppFailure>[
      ForbiddenFailure(reasonCode: 'role_mismatch'),
      NotFoundFailure(),
      GoneFailure(),
    ]) {
      testWidgets(
        'profile ${failure.kind.name} exit selects Requests repeatedly ${locale.languageCode}',
        (tester) async {
          _reduceMotion(tester);
          final semantics = tester.ensureSemantics();
          try {
            _registerTerminalProfileFailure(failure);
            final prefs = await SharedPreferences.getInstance();
            await tester.pumpWidget(
              _routerHarness(prefs, role: UserRole.client, locale: locale),
            );
            await _settle(tester);
            for (var attempt = 0; attempt < 2; attempt++) {
              await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
              await _settle(tester);
              expect(
                find.bySemanticsIdentifier('customer_profile_load_error'),
                findsOneWidget,
              );
              await tester.tap(
                find.bySemanticsIdentifier('customer_profile_load_exit_cta'),
              );
              await _settle(tester);
              expect(
                find.bySemanticsIdentifier('customer_profile_load_error'),
                findsNothing,
              );
              expect(
                tester
                    .widget<JeebPillNav>(find.byType(JeebPillNav))
                    .selectedIndex,
                0,
              );
              expect(tester.takeException(), isNull);
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets(
    'shell tab changes emit screen navigation and update API screen context',
    (tester) async {
      _reduceMotion(tester);
      final sink = _FakeObsSink();
      Observability.instance
        ..sink = sink
        ..setSessionForTest('shell-session');
      ObservabilityConfig.instance.enabled = true;
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_harness(prefs, role: UserRole.client));
      await _settle(tester);

      await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
      await _settle(tester);

      expect(Observability.instance.currentScreen, '/shell/profile');
      final event = sink.events.whereType<ObsScreenEvent>().single;
      expect(event.action, 'tab');
      expect(event.route, '/shell/profile');
      expect(event.name, 'profile');
      expect(event.previousRoute, '/shell/requests');
    },
    skip: !kObsCompiledIn,
  );

  testWidgets('client role: no jeeber wording anywhere in the nav', (
    tester,
  ) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    expect(_labels(tester), const <String>[
      'Requests',
      'Delivery',
      'Deliver',
      'Earn',
      'Profile',
    ]);
  });

  testWidgets('jeeber role: "Requests" names the incoming feed slot, and the '
      'client compose surface becomes "My Requests"', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.jeeber));
    await _settle(tester);

    final labels = _labels(tester);
    expect(labels, const <String>[
      'My Requests',
      'Deliveries',
      'Requests',
      'Earnings',
      'Profile',
    ]);
    // The frozen ids did NOT move with the wording.
    expect(
      tester
          .widget<JeebPillNav>(find.byType(JeebPillNav))
          .items
          .map((JeebPillNavItem i) => i.identifier),
      const <String>[
        'shell_tab_requests',
        'shell_tab_delivery',
        'shell_tab_dashboard',
        'shell_tab_earnings',
        'shell_tab_profile',
      ],
    );
  });

  testWidgets('root BACK returns to the landing tab instead of exiting', (
    tester,
  ) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
    await _settle(tester);
    expect(
      tester.widget<JeebPillNav>(find.byType(JeebPillNav)).selectedIndex,
      4,
    );

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(
      tester.widget<JeebPillNav>(find.byType(JeebPillNav)).selectedIndex,
      0,
    );
    // The shell is still mounted — the first BACK never tore the task down.
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('BACK on the landing tab warns first rather than exiting', (
    tester,
  ) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('under go_router, root BACK is intercepted and never exits', (
    tester,
  ) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_routerHarness(prefs, role: UserRole.client));
    await _settle(tester);

    await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
    await _settle(tester);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await _settle(tester);
    expect(
      tester.widget<JeebPillNav>(find.byType(JeebPillNav)).selectedIndex,
      0,
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('a route pushed over the shell still pops normally on BACK', (
    tester,
  ) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_routerHarness(prefs, role: UserRole.client));
    await _settle(tester);

    final BuildContext ctx = tester.element(find.byType(ShellScreen));
    GoRouter.of(ctx).push('/pushed');
    await _settle(tester);
    expect(find.text('pushed route'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await _settle(tester);

    expect(find.text('pushed route'), findsNothing);
    expect(find.text('Press back again to exit'), findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('the /settings hub has exactly one in-app entry: the Profile-tab '
      'gear', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    // The Requests tab keeps its two header actions and gains no gear.
    expect(
      find.bySemanticsIdentifier('orders_home_wallet_chip'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('orders_home_settings'), findsNothing);

    await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
    await _settle(tester);
    expect(
      find.bySemanticsIdentifier('customer_profile_settings'),
      findsOneWidget,
    );
  });
}
