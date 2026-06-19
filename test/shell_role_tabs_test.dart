import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _StubEarningsRepository implements EarningsRepository {
  @override
  Future<EarningsSummary> fetchEarnings({
    required String jeeberId,
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
    required String jeeberId,
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
}) {
  // NOTE: the shell deliberately does NOT provide a global AvailabilityCubit.
  // The Jeeber dashboard (DashboardTab) self-provides one from DI
  // (sl<AvailabilityGateway>()), screen-scoped with its own idle ticker.
  // This harness therefore registers the gateway in DI (see setUp) and does
  // NOT inject a top-level cubit — matching production, so the role-switch
  // path is exercised exactly as it runs on device.
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
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbFromDisk);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sl.registerFactory<EarningsRepository>(() => _StubEarningsRepository());
    // DashboardTab now self-provides AvailabilityCubit from DI, so the
    // gateway it resolves must be registered — exactly as production does in
    // injection_container.dart. An in-memory gateway keeps cold-start offline
    // and deterministic.
    sl.registerLazySingleton<AvailabilityGateway>(
      InMemoryAvailabilityGateway.new,
    );
    // JEEBER-LOOP F3: DashboardTab now also self-provides a RequestFeedCubit
    // from a DI-registered RequestFeedRepository (so the Jeeber home shows the
    // active-delivery feed), so the repository it resolves must be registered
    // here too. An empty seeded feed keeps this shell/role test focused on
    // tab-swap behaviour.
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(const []),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('Client role shows Requests/DELIVERY/Profile tabs',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Requests'), findsWidgets);
    expect(find.text('Delivery'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    // Jeeber-only tabs must NOT be present.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Earnings'), findsNothing);
  });

  testWidgets('Switching to jeeber swaps to Dashboard/Earnings/Profile',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();

    final BuildContext ctx = tester.element(find.byType(ShellScreen));
    await ctx.read<RoleCubit>().setRole(UserRole.jeeber);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Requests'), findsNothing);
    expect(find.text('Delivery'), findsNothing);
  });

  testWidgets('Arabic locale renders RTL bottom-nav labels in Arabic',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الطلبات'), findsWidgets);
    expect(find.text('التوصيل'), findsWidgets);
    expect(find.text('حسابي'), findsWidgets);

    final BuildContext ctx = tester.element(find.byType(ShellScreen));
    expect(Directionality.of(ctx), TextDirection.rtl);
  });

  testWidgets('Role switch resets selected tab to 0 so we never land on a removed tab',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();

    // Tap the Delivery destination (client-only, index 1).
    await tester.tap(find.text('Delivery').last);
    await tester.pumpAndSettle();

    final BuildContext ctx = tester.element(find.byType(ShellScreen));
    await ctx.read<RoleCubit>().setRole(UserRole.jeeber);
    await tester.pumpAndSettle();

    // After switching to jeeber, tab 0 (Dashboard) should be active.
    expect(find.byKey(const Key('dashboard-tab-root')), findsOneWidget);
  });
}
