// THE WIRE, not just the mechanism.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/lifecycle/route_visibility.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/router/app_route_observer.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/features/shell/tabs/home_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Counts snapshot loads. The per-load WIRE fan-out is asserted separately in
/// `client_home_offscreen_push_budget_test.dart` against the real Dio repository;
/// what matters here is whether a load happens at all.
class _CountingRepository implements ClientHomeRepository {
  int loads = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    loads++;
    return const ClientHomeSnapshot(
      inProgress: [],
      pending: [],
      replies: [],
      recentDeliveries: [],
    );
  }
}

Widget _app({required Widget home}) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  // The PRODUCTION observer, the one `AppRouter` installs.
  navigatorObservers: <NavigatorObserver>[appRouteObserver],
  home: home,
);

Future<void> _pushOnTop(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('pushed route')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _popBack(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'RouteVisibilityScope: a descendant sees isOnTop flip on push and flip back '
    'on pop',
    (tester) async {
      final observed = <bool>[];
      await tester.pumpWidget(
        _app(
          home: RouteVisibilityScope(
            child: Builder(
              builder: (context) {
                observed.add(RouteVisibilityScope.isOnTop(context));
                return const Scaffold(body: Text('shell'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(observed.last, isTrue, reason: 'we are the only route');

      await _pushOnTop(tester);
      expect(
        observed.last,
        isFalse,
        reason: 'another route is on top — nothing below it is visible',
      );

      await _popBack(tester);
      expect(observed.last, isTrue, reason: 'back on top');
    },
  );

  group('the whole wire: shell route → HomeTab → ClientHomeCubit', () {
    late PushRefreshSignals bus;
    late _CountingRepository repository;

    setUp(() {
      bus = PushRefreshSignals();
      repository = _CountingRepository();
      final sl = GetIt.instance;
      if (sl.isRegistered<PushRefreshSignals>()) {
        sl.unregister<PushRefreshSignals>();
      }
      // The SAME singleton `home_tab.dart` resolves through
      sl.registerSingleton<PushRefreshSignals>(bus);
    });

    tearDown(() async {
      final sl = GetIt.instance;
      if (sl.isRegistered<PushRefreshSignals>()) {
        sl.unregister<PushRefreshSignals>();
      }
      await bus.dispose();
    });

    Future<int> pumpTab(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          home: RouteVisibilityScope(
            child: TabVisibility(
              isVisible: true,
              child: HomeTab(
                repository: repository,
                greetingNameProvider: () => null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.loads, greaterThanOrEqualTo(1), reason: 'cold load');
      final cold = repository.loads;
      return cold;
    }

    testWidgets(
      'CONTROL — tab on screen and on top: an order push DOES re-pull',
      (tester) async {
        final cold = await pumpTab(tester);

        bus.signal(const {RefreshTopic.order});
        await tester.pumpAndSettle();

        expect(repository.loads, cold + 1);
      },
    );

    testWidgets(
      'a route on top of the shell: an order push re-pulls NOTHING, and the pop '
      'pays exactly one catch-up read',
      (tester) async {
        final cold = await pumpTab(tester);
        await _pushOnTop(tester);

        bus.signal(const {RefreshTopic.order});
        bus.signal(const {RefreshTopic.order});
        bus.signal(const {RefreshTopic.order});
        await tester.pumpAndSettle();

        expect(
          repository.loads,
          cold,
          reason:
              'the Requests tab is mounted and selected but BEHIND another '
              'route — three pushes must cost zero reads',
        );

        await _popBack(tester);

        expect(
          repository.loads,
          cold + 1,
          reason: 'one catch-up snapshot, so nothing visible was ever stale',
        );
      },
    );
  });
}
