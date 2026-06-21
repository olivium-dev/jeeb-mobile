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
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/role_toggle_setting.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// DEFECT-C: the in-app role toggle must be MOUNTED and REACHABLE in the
/// rendered shell's Profile tab for a dual-role user (and hidden for a
/// single-role client), so they can switch client <-> jeeber via the UI.

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

  testWidgets('dual-role user sees the role toggle in the Profile tab',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client', 'jeeber']),
    );
    await tester.pumpAndSettle();
    await _openProfile(tester);

    // The server-backed Active-Role toggle section is mounted and reachable.
    expect(find.byKey(RoleToggleSetting.rootKey), findsOneWidget);
    // Its Client/Jeeber segments are present (OmdsFilterChips labels).
    expect(find.widgetWithText(RoleToggleSetting, 'Jeeber'), findsOneWidget);
    expect(find.widgetWithText(RoleToggleSetting, 'Client'), findsOneWidget);
  });

  testWidgets('single-role client does NOT see the role toggle',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client']),
    );
    await tester.pumpAndSettle();
    await _openProfile(tester);

    expect(find.byKey(RoleToggleSetting.rootKey), findsNothing);
  });

  testWidgets('toggling to jeeber flips the shell to the jeeber surface',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client', 'jeeber']),
    );
    await tester.pumpAndSettle();

    // Start on client surface.
    expect(find.text('Requests'), findsWidgets);

    await _openProfile(tester);
    // Tap the Jeeber segment of the mounted Active-Role toggle. Scope the text
    // finder to the toggle section so we hit the chip itself, not the bottom
    // bar "Jeeber"-less labels.
    final jeeberChip = find.descendant(
      of: find.byKey(RoleToggleSetting.rootKey),
      matching: find.text('Jeeber'),
    );
    expect(jeeberChip, findsOneWidget);
    await tester.tap(jeeberChip);
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(ShellScreen));
    expect(ctx.read<RoleCubit>().state, UserRole.jeeber);
    // Shell rebuilt onto the jeeber tab-set.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
  });
}
