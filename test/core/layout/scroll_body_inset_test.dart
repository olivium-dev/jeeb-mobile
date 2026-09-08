import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/layout/bottom_inset.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/settings_fakes.dart';

/// Representative 3-button soft-nav inset (~48dp). Any correct edge-to-edge
/// fix must reserve at least this much at the bottom of a scroll body so the
const double _kNavBarInsetDp = 48;

void main() {
  group('BottomInsetX.scrollBodyBottomInset', () {
    // Seeds the system nav-bar inset on the FlutterView and reads it back
    Future<double> resolveInset(
      WidgetTester tester, {
      required double navBarDp,
      bool wrapInSafeArea = false,
    }) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: navBarDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: navBarDp * dpr);
      addTearDown(tester.view.reset);

      late double captured;
      Widget probe = Builder(
        builder: (context) {
          captured = context.scrollBodyBottomInset;
          return const SizedBox();
        },
      );
      if (wrapInSafeArea) {
        probe = SafeArea(child: probe);
      }

      await tester.pumpWidget(
        MediaQuery(data: MediaQueryData.fromView(tester.view), child: probe),
      );
      return captured;
    }

    testWidgets('reserves the nav-bar inset for a full-screen scroll body', (
      tester,
    ) async {
      final inset = await resolveInset(tester, navBarDp: _kNavBarInsetDp);
      expect(inset, _kNavBarInsetDp);
    });

    testWidgets('is zero with no nav bar (gesture nav off)', (tester) async {
      final inset = await resolveInset(tester, navBarDp: 0);
      expect(inset, 0);
    });

    testWidgets('is double-pad safe — returns 0 once SafeArea consumes it', (
      tester,
    ) async {
      // If an ancestor SafeArea already reserved the bottom inset, the helper
      final inset = await resolveInset(
        tester,
        navBarDp: _kNavBarInsetDp,
        wrapInSafeArea: true,
      );
      expect(inset, 0);
    });
  });

  group('Settings list reserves the bottom nav inset (edge-to-edge)', () {
    late _SyncDelegate delegate;

    setUpAll(() {
      delegate = _SyncDelegate({
        'en': File('lib/l10n/app_en.arb').readAsStringSync(),
        'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
      });
    });

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('settings ListView bottom padding includes the nav-bar inset', (
      tester,
    ) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      addTearDown(tester.view.reset);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => LocaleCubit(
                prefs: prefs,
                deviceLocaleProvider: () => const Locale('en'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: SettingsScreen(cubit: cubit, appVersion: '1.2.3'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(
        find.byKey(const Key('settings-screen-list')),
      );
      final padding = listView.padding! as EdgeInsets;
      expect(
        padding.bottom,
        greaterThanOrEqualTo(_kNavBarInsetDp),
        reason:
            'Settings list must reserve the $_kNavBarInsetDp dp nav-bar '
            'inset so the final Account row clears the soft buttons; bottom '
            'padding was ${padding.bottom}',
      );
      // Horizontal gutter preserved.
      expect(padding.left, 16);
      expect(padding.right, 16);
    });
  });

  group('Client home list reserves the bottom nav inset (edge-to-edge)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    late _SyncDelegate delegate;

    setUpAll(() {
      delegate = _SyncDelegate({
        'en': File('lib/l10n/app_en.arb').readAsStringSync(),
        'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
      });
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final scenario in const [
        (size: Size(320, 568), scale: 1.0),
        (size: Size(360, 780), scale: 2.0),
      ]) {
        testWidgets(
          'shell last pending card clears navigation and opens its request '
          '${locale.languageCode} ${scenario.size} text ${scenario.scale}',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = scenario.size;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
            tester.view.viewPadding = const FakeViewPadding(
              top: 24,
              bottom: 48,
            );
            addTearDown(tester.view.reset);
            final semantics = tester.ensureSemantics();
            try {
              final prefs = await SharedPreferences.getInstance();
              final repo = InMemoryClientHomeRepository.fromSnapshot(
                ClientHomeSnapshot(
                  pending: [
                    for (var index = 0; index < 8; index++)
                      ClientHomeRequest(
                        id: 'clearance-pending-$index',
                        title: 'ORD-0000$index',
                        displayId: 'ORD-0000$index',
                        destinationLabel: 'Ashrafieh to Hamra',
                        itemsSummary:
                            'Documents and carefully packed groceries',
                        status: ClientRequestStatus.searching,
                      ),
                  ],
                ),
                latency: Duration.zero,
              );
              final openedRequests = <String>[];
              var composerCalls = 0;
              final router = GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => ShellScreen(
                      homeRepository: repo,
                      ordersRepository: _UnavailableOrders(),
                    ),
                  ),
                  GoRoute(
                    path: '/requests/:id/waiting',
                    name: 'waiting-no-coverage',
                    builder: (_, state) {
                      openedRequests.add(state.pathParameters['id']!);
                      return const Scaffold(body: Text('Waiting destination'));
                    },
                  ),
                  GoRoute(
                    path: '/client-location',
                    name: 'client-location',
                    builder: (_, _) {
                      composerCalls++;
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
                  child: MaterialApp.router(
                    routerConfig: router,
                    theme: AppTheme.midnight(),
                    locale: locale,
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: [
                      delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        disableAnimations: true,
                        textScaler: TextScaler.linear(scenario.scale),
                      ),
                      child: child!,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.byType(ShellScreen), findsOneWidget);
              final list = find.byKey(const Key('client-home-ready-list'));
              final position = tester
                  .state<ScrollableState>(
                    find.descendant(
                      of: list,
                      matching: find.byType(Scrollable),
                    ),
                  )
                  .position;
              expect(
                position.maxScrollExtent,
                greaterThan(position.viewportDimension),
              );
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
              expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));
              final last = find.bySemanticsIdentifier(
                'orders_home_request_row_7',
              );
              final card = tester.getRect(last);
              final viewport = tester.getRect(list);
              final create = find.bySemanticsIdentifier(
                'orders_create_request_button',
              );
              final mic = find.byKey(const Key('client-home-floating-mic'));
              final micRect = tester.getRect(mic);
              final halo = tester.getRect(
                find
                    .ancestor(
                      of: mic,
                      matching: find.byWidgetPredicate(
                        (widget) =>
                            widget is SizedBox &&
                            widget.width != null &&
                            widget.width == widget.height &&
                            widget.width! > micRect.width,
                      ),
                    )
                    .first,
              );
              final ring = tester.getRect(
                find.byKey(const Key('client-home-mic-idle-ring')),
              );
              expect(halo.intersect(ring), ring);
              expect(halo.intersect(micRect), micRect);
              final scaffold = tester.widget<Scaffold>(
                find
                    .ancestor(
                      of: find.byType(ClientHomeScreen),
                      matching: find.byType(Scaffold),
                    )
                    .first,
              );
              final navigation = tester.getRect(
                find.byWidget(scaffold.bottomNavigationBar!),
              );
              expect(viewport.top, greaterThanOrEqualTo(24));
              expect(viewport.intersect(card), card);
              for (final control in [
                tester.getRect(create),
                micRect,
                halo,
                navigation,
              ]) {
                expect(viewport.overlaps(control), isFalse);
                expect(card.overlaps(control), isFalse);
              }
              for (final control in [tester.getRect(create), micRect, halo]) {
                expect(control.bottom, lessThanOrEqualTo(navigation.top));
                expect(
                  control.bottom,
                  lessThanOrEqualTo(scenario.size.height - 48),
                );
              }
              var voiceActivations = 0;
              final voice = tester.element(mic).read<VoiceRecordingCubit>();
              expect(voice.state.isRecording, isFalse);
              final subscription = voice.stream.listen((state) {
                if (state.isRecording || state.isSending) voiceActivations++;
              });
              addTearDown(subscription.cancel);
              expect(tester.takeException(), isNull);
              await tester.tapAt(card.center);
              await tester.pumpAndSettle();
              expect(openedRequests, ['clearance-pending-7']);
              expect(find.text('Waiting destination'), findsOneWidget);
              expect(composerCalls, 0);
              expect(voiceActivations, 0);
              expect(tester.takeException(), isNull);
              router.pop();
              await tester.pumpAndSettle();
              await tester.tapAt(tester.getCenter(create));
              await tester.pumpAndSettle();
              expect(composerCalls, 1);
              expect(openedRequests, ['clearance-pending-7']);
              expect(find.text('Composer destination'), findsOneWidget);
              expect(voiceActivations, 0);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  });
}

class _UnavailableOrders implements OrderRepository {
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

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}
