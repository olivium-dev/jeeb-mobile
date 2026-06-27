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
import 'package:jeeb_mobile/features/settings/presentation/widgets/role_toggle_setting.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/features/shell/widgets/jeeber_tab_empty_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// UX LAW (S0-E2E-08): the jeeber surfaces are ADDITIVE tabs, not a mode the
/// user flips into. The in-app role *switch* (the old DEFECT-C [RoleToggleSetting]
/// mounted in the Profile tab) is therefore REMOVED — neither a single-role
/// client nor a dual-role user sees it. The dual-role user simply gets the LIVE
/// jeeber tab bodies; the single-role user gets the same tabs with EMPTY STATES.

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

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arb);
  final Map<String, String> _arb;
  @override
  bool isSupported(Locale locale) => _arb.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb[locale.languageCode]!);
  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _delegate;

Widget _harness({
  required SharedPreferences prefs,
  required List<String> availableRoles,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => LocaleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider(
        create: (_) =>
            RoleAvailabilityCubit(RoleAvailability(roles: availableRoles)),
      ),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ShellScreen(),
    ),
  );
}

Future<void> _openProfile(WidgetTester tester) async {
  // Tap the Profile destination in the bottom bar (renders Text(tab.label)).
  await tester.tap(find.text('Profile').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
    _delegate = _SyncDelegate({'en': en, 'ar': ar});
  });

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

  testWidgets('dual-role user does NOT see a role toggle in the Profile tab',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client', 'jeeber']),
    );
    await tester.pumpAndSettle();
    await _openProfile(tester);

    // The role SWITCH is gone (UX LAW: additive tabs, no mode flip).
    expect(find.byKey(RoleToggleSetting.rootKey), findsNothing);
  });

  testWidgets('single-role client does NOT see a role toggle either',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client']),
    );
    await tester.pumpAndSettle();
    await _openProfile(tester);

    expect(find.byKey(RoleToggleSetting.rootKey), findsNothing);
  });

  testWidgets('dual-role user gets the LIVE jeeber tab bodies (no empty state)',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client', 'jeeber']),
    );
    await tester.pumpAndSettle();

    // The additive Dashboard tab is kept offstage while Requests is selected,
    // so include offstage in the match.
    expect(
      find.byKey(const Key('dashboard-tab-root'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(JeeberTabEmptyState, skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('single-role client gets the jeeber tabs as EMPTY STATES',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client']),
    );
    await tester.pumpAndSettle();

    // Both additive jeeber tab bodies (Dashboard + Earnings) show the
    // become-a-jeeber empty state; the live dashboard is absent. They are kept
    // offstage by the IndexedStack while Requests is selected.
    expect(
      find.byType(JeeberTabEmptyState, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const Key('dashboard-tab-root'), skipOffstage: false),
      findsNothing,
    );
  });
}
