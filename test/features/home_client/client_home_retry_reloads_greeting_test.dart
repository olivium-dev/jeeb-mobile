// DEVICE JUDGE F1: the client home Retry re-fetched only /requests and
// /deliveries, so a failed greeting read never recovered in place.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/greeting_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowsThenSucceeds implements CustomerProfileRepository {
  int reads = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (++reads == 1) {
      throw const CustomerProfileRepositoryException.classified(
        CustomerProfileFailure.network,
        appFailure: NetworkFailure(offline: true),
      );
    }
    return const CustomerProfileViewData(name: 'Sami Fawaz');
  }
}

class _ScriptedHome implements ClientHomeRepository {
  _ScriptedHome(this._script);

  final List<ClientHomeSnapshot> _script;
  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final snapshot =
        _script[calls < _script.length ? calls : _script.length - 1];
    calls += 1;
    return snapshot;
  }
}

class _OfflineOrders implements OrderRepository {
  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async => throw const OrderRepositoryException(
    OrderRepositoryErrorKind.network,
    null,
    NetworkFailure(offline: true),
  );
}

const _offlineSnapshot = ClientHomeSnapshot(
  requestsFailure: NetworkFailure(offline: true),
  inProgressFailure: NetworkFailure(offline: true),
);

const _order = ClientHomeRequest(
  id: 'ip-1',
  title: 'Kamal Hajj',
  destinationLabel: '1 kilo potato',
  status: ClientRequestStatus.enRoute,
  tier: ClientRequestTier.flash,
  progressStep: 3,
);

Widget _host(
  ClientHomeCubit home,
  GreetingProfileCubit greeting,
  Locale l, {
  double textScale = 1,
  VoidCallback? onCreateRequest,
  ClientHomeTab initialTab = ClientHomeTab.all,
}) => wrapForTest(
  MultiBlocProvider(
    providers: [
      BlocProvider<ClientHomeCubit>.value(value: home),
      BlocProvider<GreetingProfileCubit>.value(value: greeting),
    ],
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: ClientHomeScreen(
            initialTab: initialTab,
            onCreateRequest: onCreateRequest == null
                ? null
                : (_) => onCreateRequest(),
          ),
        ),
      ),
    ),
  ),
  locale: l,
);

void main() {
  // Existing greeting cases use a tall phone; the matrix overrides this below.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(440 * 3, 956 * 3);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final size in const [Size(320, 568), Size(360, 780)]) {
      for (final textScale in const [1.0, 2.0]) {
        testWidgets('${locale.languageCode}: shell safe-area cold Retry '
            '${size.width}x${size.height} text $textScale', (tester) async {
          useReduceMotion(tester);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          final semantics = tester.ensureSemantics();
          try {
            SharedPreferences.setMockInitialValues(<String, Object>{});
            final prefs = await SharedPreferences.getInstance();
            sl.registerSingleton<CustomerProfileRepository>(
              _ThrowsThenSucceeds(),
            );
            addTearDown(() => sl.unregister<CustomerProfileRepository>());
            final home = _ScriptedHome([
              _offlineSnapshot,
              const ClientHomeSnapshot(pending: [_order]),
            ]);
            var composerCalls = 0;
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => ShellScreen(
                    homeRepository: home,
                    ordersRepository: _OfflineOrders(),
                  ),
                ),
                GoRoute(
                  path: '/create',
                  name: 'client-location',
                  builder: (_, _) {
                    composerCalls += 1;
                    return const Scaffold(body: Text('Composer destination'));
                  },
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => LocaleCubit(
                      prefs: prefs,
                      deviceLocaleProvider: () => locale,
                    ),
                  ),
                  BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
                  BlocProvider(create: (_) => RoleEligibilityCubit()),
                  BlocProvider(
                    create: (_) => RoleAvailabilityCubit(
                      const RoleAvailability(
                        roles: ['client'],
                        status: RoleAvailabilityStatus.resolved,
                      ),
                    ),
                  ),
                ],
                child: wrapForTest(
                  Theme(
                    data: AppTheme.midnight(),
                    child: Builder(
                      builder: (context) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(textScale),
                          disableAnimations: true,
                        ),
                        child: Router<Object>(
                          backButtonDispatcher: router.backButtonDispatcher,
                          routerDelegate: router.routerDelegate,
                          routeInformationParser: router.routeInformationParser,
                          routeInformationProvider:
                              router.routeInformationProvider,
                        ),
                      ),
                    ),
                  ),
                  locale: locale,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(ShellScreen), findsOneWidget);
            expect(home.calls, 1);
            expect(composerCalls, 0);
            final list = find.descendant(
              of: find.byType(ClientHomeScreen),
              matching: find.byType(ListView),
            );
            await tester.scrollUntilVisible(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.identifier == 'client_home_retry_cta',
              ),
              80,
              scrollable: find.descendant(
                of: list,
                matching: find.byType(Scrollable),
              ),
            );
            await tester.pumpAndSettle();
            final retry = find.bySemanticsIdentifier('client_home_retry_cta');
            final create = find.bySemanticsIdentifier(
              'orders_create_request_button',
            );
            final mic = find.bySemanticsIdentifier('client_home_mic_cta');
            final viewport = tester.getRect(list);
            final retryRect = tester.getRect(retry);
            final createRect = tester.getRect(create);
            final micRect = tester.getRect(mic);
            expect(viewport.top, greaterThanOrEqualTo(24));
            expect(viewport.bottom, lessThanOrEqualTo(createRect.top));
            expect(viewport.overlaps(micRect), isFalse);
            expect(retryRect.top, greaterThanOrEqualTo(viewport.top));
            expect(retryRect.bottom, lessThanOrEqualTo(viewport.bottom));
            expect(retryRect.overlaps(createRect), isFalse);
            expect(retryRect.overlaps(micRect), isFalse);
            await tester.tapAt(retryRect.center);
            await tester.pumpAndSettle();
            expect(home.calls, 2);
            expect(composerCalls, 0);
            expect(find.byType(ShellScreen), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tapAt(tester.getCenter(create));
            await tester.pumpAndSettle();
            expect(composerCalls, greaterThan(0));
            expect(find.text('Composer destination'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    for (final size in const [Size(320, 568), Size(360, 780), Size(800, 600)]) {
      for (final textScale in const [1.0, 2.0]) {
        for (final scenario in const ['cold', 'pending', 'empty']) {
          testWidgets(
            '$tag: action band $scenario ${size.width}x${size.height} '
            'text $textScale',
            (tester) async {
              useReduceMotion(tester);
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = size;
              final semantics = tester.ensureSemantics();
              final profile = _ThrowsThenSucceeds();
              final greeting = GreetingProfileCubit(repository: profile);
              addTearDown(greeting.close);
              final homeRepo = _ScriptedHome([
                switch (scenario) {
                  'cold' => _offlineSnapshot,
                  'pending' => const ClientHomeSnapshot(
                    requestsFailure: NetworkFailure(offline: true),
                    inProgress: [_order],
                  ),
                  _ => const ClientHomeSnapshot(),
                },
                const ClientHomeSnapshot(pending: [_order]),
              ]);
              final home = ClientHomeCubit(
                repository: homeRepo,
                greetingNameProvider: () => null,
              );
              addTearDown(home.close);
              var composerCalls = 0;
              await tester.pumpWidget(
                _host(
                  home,
                  greeting,
                  locale,
                  textScale: textScale,
                  initialTab: ClientHomeTab.pendingRequests,
                  onCreateRequest: () => composerCalls += 1,
                ),
              );
              await greeting.load();
              await tester.pumpAndSettle();
              expect(homeRepo.calls, 1);
              expect(profile.reads, 1);
              expect(
                home.state.status,
                scenario == 'cold'
                    ? ClientHomeStatus.failed
                    : ClientHomeStatus.ready,
              );

              final create = find.bySemanticsIdentifier(
                'orders_create_request_button',
              );
              final mic = find.bySemanticsIdentifier('client_home_mic_cta');
              final actionIdentifier = switch (scenario) {
                'cold' => 'client_home_retry_cta',
                'pending' => 'pending_retry_cta',
                _ => '_request_empty_state_new_order_button',
              };
              if (scenario != 'empty') {
                // Offscreen widgets have no exposed semantics until revealed.
                await tester.scrollUntilVisible(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.identifier == actionIdentifier,
                  ),
                  100,
                  scrollable: find.descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  ),
                );
                await tester.pumpAndSettle();
              }
              final action = find.bySemanticsIdentifier(actionIdentifier);
              expect(action, findsOneWidget);
              final actionRect = tester.getRect(action);
              final createRect = tester.getRect(create);
              final micRect = tester.getRect(mic);
              final viewportRect = tester.getRect(find.byType(ListView));

              await tester.tapAt(actionRect.center);
              await tester.pumpAndSettle();
              expect(homeRepo.calls, scenario == 'empty' ? 1 : 2);
              expect(composerCalls, scenario == 'empty' ? 1 : 0);
              expect(profile.reads, scenario == 'cold' ? 2 : 1);
              expect(actionRect.overlaps(micRect), isFalse);
              expect(actionRect.top, greaterThanOrEqualTo(0));
              expect(actionRect.bottom, lessThanOrEqualTo(size.height));
              expect(viewportRect.bottom, lessThanOrEqualTo(createRect.top));
              if (scenario != 'empty') {
                expect(actionRect.overlaps(createRect), isFalse);
                expect(actionRect.top, greaterThanOrEqualTo(viewportRect.top));
                expect(
                  actionRect.bottom,
                  lessThanOrEqualTo(viewportRect.bottom),
                );
              }
              expect(tester.takeException(), isNull);
              semantics.dispose();
            },
          );
        }
      }
    }

    testWidgets('$tag: the home retry re-issues the profile read', (
      tester,
    ) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final profile = _ThrowsThenSucceeds();
      final greeting = GreetingProfileCubit(repository: profile);
      addTearDown(greeting.close);
      final homeRepo = _ScriptedHome([
        _offlineSnapshot,
        const ClientHomeSnapshot(pending: [_order]),
      ]);
      final home = ClientHomeCubit(
        repository: homeRepo,
        greetingNameProvider: () => null,
      );
      addTearDown(home.close);

      await tester.pumpWidget(_host(home, greeting, locale));
      await greeting.load();
      await tester.pumpAndSettle();
      expect(profile.reads, 1);
      expect(homeRepo.calls, 1, reason: 'the screen loads on its first frame');
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsIdentifier('client_home_retry_cta'));
      await tester.pumpAndSettle();

      expect(profile.reads, 2, reason: 'Retry must also re-read /v1/users/me');
      expect(greeting.state.name, 'Sami Fawaz');
      expect(
        find.bySemanticsIdentifier('client_home_greeting_error'),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('$tag: pull-to-refresh re-issues the profile read', (
      tester,
    ) async {
      useReduceMotion(tester);
      final profile = _ThrowsThenSucceeds();
      final greeting = GreetingProfileCubit(repository: profile);
      addTearDown(greeting.close);
      final home = ClientHomeCubit(
        repository: _ScriptedHome([
          const ClientHomeSnapshot(pending: [_order]),
        ]),
        greetingNameProvider: () => null,
      );
      addTearDown(home.close);

      await tester.pumpWidget(_host(home, greeting, locale));
      await greeting.load();
      await tester.pumpAndSettle();
      expect(profile.reads, 1);

      await tester.fling(
        find.byKey(const Key('client-home-ready-list')),
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(profile.reads, 2, reason: 'a pull must also re-read /v1/users/me');
      expect(greeting.state.name, 'Sami Fawaz');
    });

    testWidgets('$tag: no greeting provider leaves the retry inert', (
      tester,
    ) async {
      useReduceMotion(tester);
      final semantics = tester.ensureSemantics();
      final home = ClientHomeCubit(
        repository: _ScriptedHome([
          _offlineSnapshot,
          const ClientHomeSnapshot(pending: [_order]),
        ]),
        greetingNameProvider: () => null,
      );
      addTearDown(home.close);

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<ClientHomeCubit>.value(
            value: home,
            child: const Scaffold(body: ClientHomeScreen()),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('client_home_retry_cta'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
