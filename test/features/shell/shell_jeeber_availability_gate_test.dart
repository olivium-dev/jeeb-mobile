// F2/F3: outage/50,/51,/60 — an APPROVED jeeber with 5 active deliveries was
// shown "Become a Jeeber" because a FAILED read read as "not a jeeber".
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/features/shell/tabs/dashboard_tab.dart';
import 'package:jeeb_mobile/features/shell/tabs/earnings_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
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

Widget _harness({
  required SharedPreferences prefs,
  required RoleAvailabilityCubit availability,
  Locale locale = const Locale('en'),
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            LocaleCubit(prefs: prefs, deviceLocaleProvider: () => locale),
      ),
      BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
      BlocProvider<RoleAvailabilityCubit>.value(value: availability),
    ],
    child: MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ShellScreen(),
      // The E3 illustration loops forever; pumpAndSettle only terminates on
      // the reduce-motion rest frame.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sl.registerFactory<EarningsRepository>(() => _StubEarningsRepository());
    sl.registerLazySingleton<AvailabilityGateway>(
      InMemoryAvailabilityGateway.new,
    );
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(const []),
    );
  });

  tearDown(() async => sl.reset());

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets(
      '[$tag] a FAILED availability read with no cached role renders the '
      'jeeber-tab error rungs, never the become-a-jeeber invitation',
      (tester) async {
        useReduceMotion(tester);
        final handle = tester.ensureSemantics();
        final prefs = await SharedPreferences.getInstance();
        final availability = RoleAvailabilityCubit(
          const RoleAvailability(
            status: RoleAvailabilityStatus.failed,
            failure: NetworkFailure(offline: true),
          ),
        );
        addTearDown(availability.close);

        await tester.pumpWidget(
          _harness(prefs: prefs, availability: availability, locale: locale),
        );
        await _settle(tester);
        // A non-resolved account lands on Requests; the jeeber tabs are the
        // ones under test.
        await tester.tap(find.bySemanticsIdentifier('shell_tab_dashboard'));
        await _settle(tester);

        expect(
          find.bySemanticsIdentifier('jeeber_home_error'),
          findsOneWidget,
          reason: 'F2: the Requests(dashboard) tab must say the read failed',
        );
        expect(
          find.bySemanticsIdentifier('jeeber_home_retry_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('jeeber_dashboard_empty_state'),
          findsNothing,
          reason: 'a failed read must never invite a jeeber to re-register',
        );

        await tester.tap(find.bySemanticsIdentifier('shell_tab_earnings'));
        await _settle(tester);

        expect(
          find.bySemanticsIdentifier('jeeber_earnings_error'),
          findsOneWidget,
          reason: 'F3: same read, same failure, on Earnings',
        );
        expect(
          find.bySemanticsIdentifier('jeeber_earnings_retry_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('jeeber_earnings_empty_state'),
          findsNothing,
        );
        handle.dispose();
      },
    );

    testWidgets(
      '[$tag] a RESOLVED read without the jeeber role still invites',
      (tester) async {
        useReduceMotion(tester);
        final handle = tester.ensureSemantics();
        final prefs = await SharedPreferences.getInstance();
        final availability = RoleAvailabilityCubit(
          const RoleAvailability(
            roles: ['client'],
            status: RoleAvailabilityStatus.resolved,
          ),
        );
        addTearDown(availability.close);

        await tester.pumpWidget(
          _harness(prefs: prefs, availability: availability, locale: locale),
        );
        await _settle(tester);
        await tester.tap(find.bySemanticsIdentifier('shell_tab_dashboard'));
        await _settle(tester);

        expect(
          find.bySemanticsIdentifier('jeeber_dashboard_empty_state'),
          findsOneWidget,
        );
        expect(find.bySemanticsIdentifier('jeeber_home_error'), findsNothing);

        await tester.tap(find.bySemanticsIdentifier('shell_tab_earnings'));
        await _settle(tester);

        expect(
          find.bySemanticsIdentifier('jeeber_earnings_empty_state'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('jeeber_earnings_error'),
          findsNothing,
        );
        handle.dispose();
      },
    );
    testWidgets(
      '[$tag] a FAILED read with a CACHED client role still invites',
      (tester) async {
        useReduceMotion(tester);
        final handle = tester.ensureSemantics();
        final prefs = await SharedPreferences.getInstance();
        final availability = RoleAvailabilityCubit(
          const RoleAvailability(
            roles: ['client'],
            status: RoleAvailabilityStatus.failed,
            failure: NetworkFailure(offline: true),
          ),
        );
        addTearDown(availability.close);

        await tester.pumpWidget(
          _harness(prefs: prefs, availability: availability, locale: locale),
        );
        await _settle(tester);
        await tester.tap(find.bySemanticsIdentifier('shell_tab_dashboard'));
        await _settle(tester);

        expect(
          find.bySemanticsIdentifier('jeeber_dashboard_empty_state'),
          findsOneWidget,
          reason: 'a cached client role already answers "not a jeeber"',
        );
        expect(find.bySemanticsIdentifier('jeeber_home_error'), findsNothing);

        await tester.tap(find.bySemanticsIdentifier('shell_tab_earnings'));
        await _settle(tester);

        expect(
          find.bySemanticsIdentifier('jeeber_earnings_empty_state'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('jeeber_earnings_error'),
          findsNothing,
        );
        handle.dispose();
      },
    );
  }

  testWidgets(
    'an UNRESOLVED read renders the loading rungs, not the invitation',
    (tester) async {
      useReduceMotion(tester);
      final handle = tester.ensureSemantics();
      final prefs = await SharedPreferences.getInstance();
      final availability = RoleAvailabilityCubit()..beginLoad();
      addTearDown(availability.close);

      await tester.pumpWidget(
        _harness(prefs: prefs, availability: availability),
      );
      await _settle(tester);
      await tester.tap(find.bySemanticsIdentifier('shell_tab_dashboard'));
      await _settle(tester);

      expect(find.bySemanticsIdentifier('jeeber_home_loading'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_dashboard_empty_state'),
        findsNothing,
      );

      await tester.tap(find.bySemanticsIdentifier('shell_tab_earnings'));
      await _settle(tester);

      expect(
        find.bySemanticsIdentifier('jeeber_earnings_loading'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_earnings_empty_state'),
        findsNothing,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'a FAILED read with a CACHED jeeber role keeps the live jeeber bodies',
    (tester) async {
      useReduceMotion(tester);
      final handle = tester.ensureSemantics();
      final prefs = await SharedPreferences.getInstance();
      final availability = RoleAvailabilityCubit(
        const RoleAvailability(
          roles: ['client', 'jeeber'],
          status: RoleAvailabilityStatus.failed,
          failure: NetworkFailure(offline: true),
        ),
      );
      addTearDown(availability.close);

      await tester.pumpWidget(
        _harness(prefs: prefs, availability: availability),
      );
      await _settle(tester);

      // BUG-1 still holds off a cached role: the jeeber LANDS on the feed.
      expect(find.byType(DashboardTab), findsOneWidget);
      expect(find.bySemanticsIdentifier('jeeber_home_error'), findsNothing);
      expect(
        find.bySemanticsIdentifier('jeeber_dashboard_empty_state'),
        findsNothing,
      );

      await tester.tap(find.bySemanticsIdentifier('shell_tab_earnings'));
      await _settle(tester);

      expect(find.byType(EarningsTab), findsOneWidget);
      expect(find.bySemanticsIdentifier('jeeber_earnings_error'), findsNothing);
      expect(
        find.bySemanticsIdentifier('jeeber_earnings_empty_state'),
        findsNothing,
      );
      handle.dispose();
    },
  );

  testWidgets('the error rung retries through the attached refresher', (
    tester,
  ) async {
    useReduceMotion(tester);
    final handle = tester.ensureSemantics();
    final prefs = await SharedPreferences.getInstance();
    var retries = 0;
    final availability = RoleAvailabilityCubit(
      const RoleAvailability(
        status: RoleAvailabilityStatus.failed,
        failure: NetworkFailure(offline: true),
      ),
    )..attachRefresher(() async => retries++);
    addTearDown(availability.close);

    await tester.pumpWidget(_harness(prefs: prefs, availability: availability));
    await _settle(tester);
    await tester.tap(find.bySemanticsIdentifier('shell_tab_dashboard'));
    await _settle(tester);

    await tester.tap(find.bySemanticsIdentifier('jeeber_home_retry_cta'));
    await _settle(tester);

    expect(retries, 1);
    handle.dispose();
  });
}
