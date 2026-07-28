import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/features/shell/tabs/dashboard_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

const _rootFreeInterval = Duration(seconds: 1);
const _oneMinute = Duration(seconds: 60);
const _almostOneMinute = Duration(seconds: 59);
const _controlIntervals = 6;

class _CountingActiveDeliveriesRepository
    implements ActiveDeliveriesRepository {
  int calls = 0;

  @override
  Future<List<ActiveDeliverySummary>> listActive() {
    calls++;
    return Future<List<ActiveDeliverySummary>>.value(
      const <ActiveDeliverySummary>[],
    );
  }
}

class _UnregisteredKycGate implements JeeberKycStatusGate {
  const _UnregisteredKycGate();

  @override
  JeeberKycStatus get status => JeeberKycStatus.none;

  @override
  bool get isApproved => false;
}

LocalizationsDelegate<AppLocalizations> _loadSyncDelegate() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  return _SyncAppLocalizationsDelegate(<String, String>{'en': en, 'ar': ar});
}

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

class _DashboardFixture {
  _DashboardFixture(this.delegate)
    : activeRepository = _CountingActiveDeliveriesRepository(),
      feedRepository = SeededRequestFeedRepository(const []),
      pushSignals = PushRefreshSignals(),
      visibility = ValueNotifier<bool>(true) {
    router = _router(visibility);
  }

  final LocalizationsDelegate<AppLocalizations> delegate;
  final _CountingActiveDeliveriesRepository activeRepository;
  final SeededRequestFeedRepository feedRepository;
  final PushRefreshSignals pushSignals;
  final ValueNotifier<bool> visibility;
  late final GoRouter router;

  Future<void> install() async {
    await sl.reset();
    sl.registerSingleton<JeeberKycStatusGate>(const _UnregisteredKycGate());
    sl.registerSingleton<AvailabilityGateway>(InMemoryAvailabilityGateway());
    sl.registerSingleton<RequestFeedRepository>(feedRepository);
    sl.registerSingleton<ActiveDeliveriesRepository>(activeRepository);
    sl.registerSingleton<PushRefreshSignals>(pushSignals);
  }

  Widget get app => MaterialApp.router(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  );

  Future<void> dispose() async {
    await sl.reset();
    await feedRepository.dispose();
    await pushSignals.dispose();
    visibility.dispose();
    router.dispose();
  }
}

GoRouter _router(ValueListenable<bool> visibility) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visibility,
            builder: (context, isVisible, child) =>
                TabVisibility(isVisible: isVisible, child: child!),
            child: const DashboardTab(),
          ),
        ),
      ),
      GoRoute(
        path: '/jeeber/onboarding',
        name: 'jeeber-onboarding',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/jeeber/requests/:id',
        name: 'jeeber-request-detail',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
}

ActiveDeliveriesCubit _activeCubit(WidgetTester tester) {
  final context = tester.element(find.byType(JeeberHomeScreen));
  return context.read<ActiveDeliveriesCubit>();
}

Future<_DashboardFixture> _pumpDashboard(
  WidgetTester tester,
  LocalizationsDelegate<AppLocalizations> delegate,
) async {
  final fixture = _DashboardFixture(delegate);
  await fixture.install();
  addTearDown(fixture.dispose);
  await tester.pumpWidget(fixture.app);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return fixture;
}

Future<void> _pumpIntervals(
  WidgetTester tester, {
  int count = _controlIntervals,
}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(_oneMinute);
    await tester.pump();
  }
}

Future<void> _driveToBackground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _driveToForeground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  late LocalizationsDelegate<AppLocalizations> delegate;

  setUpAll(() {
    delegate = _loadSyncDelegate();
  });

  tearDown(AppLifecycleGate.debugReset);

  test(
    'AC5 F10 poller is running and ticks with no root gate install and no MaterialApp',
    () {
      FakeAsync().run((async) {
        final repository = _CountingActiveDeliveriesRepository();
        final cubit = ActiveDeliveriesCubit(
          repository: repository,
          pollInterval: _rootFreeInterval,
        );

        cubit.start();
        async.flushMicrotasks();
        final initialLoad = repository.calls;

        expect(initialLoad, 1);
        expect(cubit.debugPoller.isRunning, isTrue);

        for (var index = 0; index < 3; index++) {
          async.elapse(_rootFreeInterval);
          async.flushMicrotasks();
        }

        expect(repository.calls, initialLoad + 3);
        expect(cubit.debugPoller.debugTickCount, 3);

        unawaited(cubit.close());
        async.flushMicrotasks();
        expect(cubit.debugPoller.isRunning, isFalse);
        expect(async.periodicTimerCount, isZero);
      });
    },
  );

  testWidgets(
    'AC1 F10 polls once per 60s safety-net interval while visible and foreground',
    (tester) async {
      final gate = ManualAppLifecycleGate(isForeground: false);
      AppLifecycleGate.install(gate);
      final fixture = await _pumpDashboard(tester, delegate);
      final cubit = _activeCubit(tester);

      expect(cubit.debugPoller.isRunning, isFalse);
      gate.setForeground(true);
      await tester.pump();
      expect(cubit.debugPoller.isRunning, isTrue);
      final visibleBaseline = fixture.activeRepository.calls;

      await tester.pump(_almostOneMinute);
      await tester.pump();
      expect(
        fixture.activeRepository.calls,
        visibleBaseline,
        reason: 'the demoted safety net must not tick before 60 seconds',
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(fixture.activeRepository.calls, visibleBaseline + 1);

      await _pumpIntervals(tester, count: _controlIntervals - 1);

      expect(
        fixture.activeRepository.calls,
        visibleBaseline + _controlIntervals,
        reason:
            'six full intervals provide 6:0 headroom over a dead or inverted '
            'presence fixture',
      );
      expect(cubit.debugPoller.isRunning, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'AC2 F10 issues zero timer-driven GETs while the Dashboard tab is hidden',
    (tester) async {
      final gate = ManualAppLifecycleGate(isForeground: false);
      AppLifecycleGate.install(gate);
      final fixture = await _pumpDashboard(tester, delegate);
      final cubit = _activeCubit(tester);

      gate.setForeground(true);
      await tester.pump();
      final visibleBaseline = fixture.activeRepository.calls;
      await _pumpIntervals(tester);
      expect(
        fixture.activeRepository.calls,
        visibleBaseline + _controlIntervals,
        reason:
            'the same unregistered-Dashboard fixture and listActive seam must '
            'produce six visible timer GETs before its hidden zero is trusted',
      );

      fixture.visibility.value = false;
      await tester.pump();
      expect(cubit.debugPoller.isRunning, isFalse);
      final hiddenBaseline = fixture.activeRepository.calls;

      await _pumpIntervals(tester);

      expect(fixture.activeRepository.calls, hiddenBaseline);
      expect(cubit.debugPoller.isRunning, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'AC3 F10 (b02 read economics) a push while the Dashboard tab is hidden '
    'costs ZERO reads and is paid with exactly ONE on refocus',
    (tester) async {
      // ⚠️ THIS ASSERTION WAS INVERTED ON PURPOSE. It previously read "still
      // refreshes on a push signal while the Dashboard tab is hidden" and
      // asserted `hiddenBaseline + 1` — a `GET /v1/deliveries?role=jeeber` for a
      // card behind the active-delivery / request-detail route. The GUARANTEE
      // that assertion existed to protect is "a hidden dashboard is never left
      // stale", and it is intact and asserted below: the read is DEFERRED, not
      // dropped, and lands the moment the surface is looked at. What changed is
      // only WHEN it is paid — see `core/lifecycle/deferred_refresh_gate.dart`.
      final gate = ManualAppLifecycleGate(isForeground: false);
      AppLifecycleGate.install(gate);
      final fixture = await _pumpDashboard(tester, delegate);
      final cubit = _activeCubit(tester);

      gate.setForeground(true);
      await tester.pump();
      fixture.visibility.value = false;
      await tester.pump();
      expect(cubit.debugPoller.isRunning, isFalse);
      final hiddenBaseline = fixture.activeRepository.calls;

      // Three pushes while nobody can see the card.
      fixture.pushSignals.signalStatusChange();
      fixture.pushSignals.signalStatusChange();
      fixture.pushSignals.signalStatusChange();
      await tester.pump();

      expect(
        fixture.activeRepository.calls,
        hiddenBaseline,
        reason: 'an invisible card must not read; the debt is recorded instead',
      );
      expect(cubit.debugPoller.isRunning, isFalse);

      // Refocus pays the debt ONCE — not three times, and not twice (the
      // deferred push read and the refocus read collapse through the cubit's
      // single-flight latch).
      fixture.visibility.value = true;
      await tester.pump();
      await tester.pump();

      expect(
        fixture.activeRepository.calls,
        hiddenBaseline + 1,
        reason: 'no staleness, and no fan-out: exactly one catch-up read',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('AC4 F10 refetches exactly once on Dashboard tab refocus', (
    tester,
  ) async {
    final gate = ManualAppLifecycleGate(isForeground: false);
    AppLifecycleGate.install(gate);
    final fixture = await _pumpDashboard(tester, delegate);
    final cubit = _activeCubit(tester);

    gate.setForeground(true);
    await tester.pump();
    fixture.visibility.value = false;
    await tester.pump();
    expect(cubit.debugPoller.isRunning, isFalse);
    final hiddenBaseline = fixture.activeRepository.calls;

    fixture.visibility.value = true;
    await tester.pump();

    expect(fixture.activeRepository.calls, hiddenBaseline + 1);
    expect(cubit.debugPoller.isRunning, isTrue);

    await tester.pump(_almostOneMinute);
    await tester.pump();
    expect(
      fixture.activeRepository.calls,
      hiddenBaseline + 1,
      reason:
          'the sub-interval window prevents the 60s safety net from masking '
          'the one visibility-resume fetch',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('AC6 F10 issues zero GETs while the app is backgrounded', (
    tester,
  ) async {
    await _driveToBackground(tester);
    final bindingGate = WidgetsBindingAppLifecycleGate();
    AppLifecycleGate.install(bindingGate);
    addTearDown(bindingGate.dispose);
    await _driveToForeground(tester);
    final fixture = await _pumpDashboard(tester, delegate);
    final cubit = _activeCubit(tester);

    expect(cubit.debugPoller.isRunning, isTrue);
    final foregroundBaseline = fixture.activeRepository.calls;
    await _pumpIntervals(tester);
    expect(
      fixture.activeRepository.calls,
      foregroundBaseline + _controlIntervals,
      reason:
          'six binding-driven foreground intervals provide the non-zero '
          'presence arm before the background absence assertion',
    );

    await _driveToBackground(tester);
    expect(cubit.debugPoller.isRunning, isFalse);
    final backgroundBaseline = fixture.activeRepository.calls;
    await _pumpIntervals(tester);

    expect(fixture.activeRepository.calls, backgroundBaseline);
    expect(cubit.debugPoller.isRunning, isFalse);

    await _driveToForeground(tester);
    expect(fixture.activeRepository.calls, backgroundBaseline + 1);
    expect(cubit.debugPoller.isRunning, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
