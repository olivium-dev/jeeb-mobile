// G3 badge render + clear: BadgeCountCubit was incremented on every push but
// rendered by ZERO widgets. The shell's Dashboard (feed) tab icon now carries
// an M3 count badge for the UNSEEN OPEN REQUESTS (newRequests), and viewing
// the feed clears it (FeedResumeRefetcher) — so a dismissed push always
// leaves a visible trail: badge → feed.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _StubEarningsRepository implements EarningsRepository {
  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      const EarningsSummary(
        totalCashEarned: 0,
        feesPaid: 0,
        currency: 'USD',
        deliveryCount: 0,
      );

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      '/tmp/earnings.pdf';
}

Widget _harness({
  required SharedPreferences prefs,
  required BadgeCountCubit badge,
}) {
  // Mirrors test/shell_role_tabs_test.dart: DashboardTab self-provides its
  // cubits from DI (registered in setUp); a jeeber RoleAvailability lights up
  // the live dashboard body so FeedResumeRefetcher is mounted.
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => const Locale('en'),
        ),
      ),
      BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
      BlocProvider(
        create: (_) => RoleAvailabilityCubit(
          const RoleAvailability(roles: ['client', 'jeeber']),
        ),
      ),
      BlocProvider.value(value: badge),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
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
}

void main() {
  late BadgeCountCubit badge;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    badge = BadgeCountCubit();
    sl.registerFactory<EarningsRepository>(() => _StubEarningsRepository());
    sl.registerLazySingleton<AvailabilityGateway>(
      InMemoryAvailabilityGateway.new,
    );
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(const []),
    );
  });

  tearDown(() async {
    await badge.close();
    await sl.reset();
  });

  testWidgets(
      'new-request pushes badge the Dashboard tab icon while another tab is '
      'selected, and VIEWING the feed clears it', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs, badge: badge));
    await tester.pumpAndSettle();

    // A jeeber lands ON the dashboard (BUG-1), so step off it first — the
    // badge counts requests arriving while the jeeber is NOT looking.
    await tester.tap(find.bySemanticsIdentifier('shell_tab_requests'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('shell_tab_dashboard_badge'),
        findsNothing);

    // Two new-request pushes land (what push_notification_handler emits).
    badge
      ..increment(isNewRequest: true)
      ..increment(isNewRequest: true);
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('shell_tab_dashboard_badge'),
        findsOneWidget, reason: 'the tracked count must actually RENDER (G3)');
    expect(find.text('2'), findsOneWidget,
        reason: 'the badge shows the unseen open-request count');

    // Viewing the feed clears the badge (FeedResumeRefetcher).
    await tester.tap(find.bySemanticsIdentifier('shell_tab_dashboard'));
    await tester.pumpAndSettle();
    expect(badge.state.newRequests, 0,
        reason: 'viewing the feed marks the requests seen');
    expect(find.bySemanticsIdentifier('shell_tab_dashboard_badge'),
        findsNothing);
    expect(badge.state.unread, 2,
        reason: 'the inbox total is cleared by the inbox, not the feed');
  });

  testWidgets('non-request pushes (chat/offer) do NOT badge the feed tab',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs, badge: badge));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('shell_tab_requests'));
    await tester.pumpAndSettle();

    badge.increment(); // e.g. a chat push
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('shell_tab_dashboard_badge'),
        findsNothing,
        reason: 'the feed badge counts unseen OPEN REQUESTS, not all pushes');
  });

  testWidgets(
      'a push landing WHILE the feed is on screen never shows a badge '
      '(the jeeber is already looking)', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs, badge: badge));
    await tester.pumpAndSettle(); // lands on the dashboard (jeeber landing)

    badge.increment(isNewRequest: true);
    await tester.pumpAndSettle();

    expect(badge.state.newRequests, 0);
    expect(find.bySemanticsIdentifier('shell_tab_dashboard_badge'),
        findsNothing);
  });
}
