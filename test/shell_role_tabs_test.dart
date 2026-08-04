import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/features/shell/widgets/jeeber_tab_empty_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// UX LAW (S0-E2E-08): the shell is ADDITIVE, not role-gated. Every user sees
/// the same five destinations — Requests / Delivery / Dashboard / Earnings /
/// Profile. A non-jeeber sees the jeeber tabs with EMPTY STATES; a jeeber sees

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

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _harness({
  required SharedPreferences prefs,
  Locale locale = const Locale('en'),
  List<String>? availableRoles,
}) {
  // The shell deliberately does NOT provide a global AvailabilityCubit; the
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => locale,
        ),
      ),
      BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
      if (availableRoles != null)
        BlocProvider(
          create: (_) =>
              RoleAvailabilityCubit(RoleAvailability(roles: availableRoles)),
        ),
    ],
    child: BlocBuilder<LocaleCubit, Locale>(
      builder: (context, l) => MaterialApp(
        theme: AppTheme.light(),
        locale: l,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          _syncDelegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ShellScreen(),
        // JeebEmptyState's E1 illustration loops ∞ by design (03-MOTION-NOTES
        // §E1): pumpAndSettle only terminates under reduce motion.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbFromDisk);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sl.registerFactory<EarningsRepository>(() => _StubEarningsRepository());
    // DashboardTab self-provides AvailabilityCubit from DI, so the gateway it
    sl.registerLazySingleton<AvailabilityGateway>(
      InMemoryAvailabilityGateway.new,
    );
    // DashboardTab also self-provides a RequestFeedCubit from a DI-registered
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(const []),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('shell shows all five additive destinations for every user',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();
    // Home's in-memory repo resolves behind a 150ms fake-latency timer that
    // schedules no frame; advance past it so none is left pending.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // The regular-user surfaces.
    expect(find.text('Requests'), findsWidgets);
    expect(find.text('Delivery'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    // The ADDITIVE jeeber tabs are present for a regular user too (UX LAW),
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
  });

  testWidgets('non-jeeber sees the jeeber tabs as EMPTY STATES (no live body)',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client']),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Both jeeber tab bodies (Dashboard + Earnings) render the become-a-jeeber
    expect(
      find.byType(JeeberTabEmptyState, skipOffstage: false),
      findsNWidgets(2),
    );
    // ...and NOT the live jeeber dashboard.
    expect(
      find.byKey(const Key('dashboard-tab-root'), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('jeeber sees the LIVE jeeber dashboard body (no empty state)',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client', 'jeeber']),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // The live jeeber home is rendered (its root key is present in the
    expect(
      find.byKey(const Key('dashboard-tab-root'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(JeeberTabEmptyState, skipOffstage: false),
      findsNothing,
    );
    // The tab set is unchanged — all five destinations are still present.
    expect(find.text('Requests'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
  });

  testWidgets('switching the Jeeber tab into view does not change the tab set',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Tap the additive Dashboard destination (index 2).
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();

    // All five destinations are still present — additive, never swapped.
    expect(find.text('Requests'), findsWidgets);
    expect(find.text('Delivery'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('Arabic locale renders RTL bottom-nav labels in Arabic',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs, locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('الطلبات'), findsWidgets);
    expect(find.text('التوصيل'), findsWidgets);
    expect(find.text('حسابي'), findsWidgets);

    final BuildContext ctx = tester.element(find.byType(ShellScreen));
    expect(Directionality.of(ctx), TextDirection.rtl);
  });
}
