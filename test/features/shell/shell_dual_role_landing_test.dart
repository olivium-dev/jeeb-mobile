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
import 'package:jeeb_mobile/features/shell/tabs/home_tab.dart';
import 'package:jeeb_mobile/features/shell/widgets/jeeber_tab_empty_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// BUG-1 (sprint-008, Lane B / known-bug #1): dual-role shell routing.
///
/// A dual-role jeeber (seed `..0002` Karim, `available_roles: [client, jeeber]`)
/// MUST land on the **Jeeber surface** (the additive Dashboard tab — the
/// incoming-request feed, Core Flow step 2), NOT the client surface. A plain
/// client (`available_roles: [client]`) MUST land on the client surface
/// (Requests). The landing tab is derived from the resolved capabilities
/// (gateway Auth/Capabilities → [RoleAvailabilityCubit]), never a hardcoded
/// index — and, per the CORE UX RULE, this is NOT a mode switch: every user
/// sees the SAME five additive destinations regardless of where they land.
///
/// Pre-fix the shell hardcoded the landing index to 0, so Karim opened on the
/// client Requests tab and the jeeber feed (steps 2-3) was unreachable on
/// cold-start.

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
  // The shell deliberately does NOT provide a global AvailabilityCubit; the
  // Jeeber dashboard self-provides one from DI (registered in setUp), exactly
  // as production does. [availableRoles] seeds the RoleAvailabilityCubit the
  // additive shell watches — its `jeeber` membership both lights up the live
  // jeeber bodies AND drives the BUG-1 landing tab.
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => LocaleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
      BlocProvider(
        create: (_) =>
            RoleAvailabilityCubit(RoleAvailability(roles: availableRoles)),
      ),
    ],
    child: BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) => MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          _delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ShellScreen(),
      ),
    ),
  );
}

/// Asserts the `selected` semantics flag on a bottom-nav tab by its stable
/// `shell_tab_<id>` identifier — the locale-independent signal QA uses too.
void _expectTabSelected(
  WidgetTester tester,
  String tabId, {
  required bool selected,
}) {
  expect(
    tester.getSemantics(find.bySemanticsIdentifier('shell_tab_$tabId')),
    containsSemantics(isSelected: selected),
  );
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
    // The live Jeeber dashboard self-provides AvailabilityCubit + RequestFeed
    // from DI, so the gateway/repo it resolves must be registered — exactly as
    // production does. In-memory / empty keeps cold-start offline + focused.
    sl.registerLazySingleton<AvailabilityGateway>(
      InMemoryAvailabilityGateway.new,
    );
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(const []),
    );
  });

  tearDown(() async => sl.reset());

  testWidgets(
      'dual-role jeeber LANDS on the Jeeber shell (Dashboard surface), not the '
      'client shell', (tester) async {
    final handle = tester.ensureSemantics();
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client', 'jeeber']),
    );
    await tester.pumpAndSettle();

    // The LIVE jeeber dashboard body is the on-screen (onstage) tab — i.e. the
    // shell landed the jeeber on the Jeeber surface. IndexedStack keeps the
    // other tabs mounted but offstage, so the default (skipOffstage) finder
    // only matches when Dashboard is the SELECTED tab.
    expect(
      find.byKey(const Key('dashboard-tab-root')),
      findsOneWidget,
      reason: 'A dual-role jeeber must land on the live Jeeber Dashboard tab.',
    );

    // ...and the bottom-nav reflects it: the Jeeber (Dashboard) tab is selected,
    // the client Requests tab is not.
    _expectTabSelected(tester, 'dashboard', selected: true);
    _expectTabSelected(tester, 'requests', selected: false);

    // CORE UX RULE: this is additive, not a mode switch — the client tabs are
    // STILL present (just not the landing tab).
    expect(find.bySemanticsIdentifier('shell_tab_requests'), findsOneWidget);
    expect(find.bySemanticsIdentifier('shell_tab_delivery'), findsOneWidget);
    expect(find.bySemanticsIdentifier('shell_tab_profile'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('plain client LANDS on the client shell (Requests surface)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _harness(prefs: prefs, availableRoles: const ['client']),
    );
    await tester.pumpAndSettle();

    // The client Requests home is the on-screen tab.
    expect(
      find.byType(HomeTab),
      findsOneWidget,
      reason: 'A plain client must land on the Requests (client) surface.',
    );
    _expectTabSelected(tester, 'requests', selected: true);
    _expectTabSelected(tester, 'dashboard', selected: false);

    // The additive jeeber tabs are still present, but render their EMPTY STATES
    // offstage (a non-jeeber never sees a live jeeber body, and never landed
    // there).
    expect(
      find.byKey(const Key('dashboard-tab-root'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byType(JeeberTabEmptyState, skipOffstage: false),
      findsNWidgets(2),
    );

    handle.dispose();
  });

  testWidgets(
      'a manual tab tap sticks even when capabilities resolve to jeeber later',
      (tester) async {
    // Simulates the cold-start race: the shell first builds with NO resolved
    // capabilities (getMe pending → client surface), the user taps Delivery,
    // and only then does getMe resolve to a dual-role jeeber. The user's
    // explicit choice must NOT be yanked to the Dashboard.
    final availability = RoleAvailabilityCubit();
    addTearDown(availability.close);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LocaleCubit(prefs: prefs)),
          BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
          BlocProvider(create: (_) => RoleEligibilityCubit()),
          BlocProvider.value(value: availability),
        ],
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) => MaterialApp(
            theme: AppTheme.light(),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              _delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const ShellScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    // Pre-resolution: a no-capability shell lands on Requests.
    _expectTabSelected(tester, 'requests', selected: true);

    // User explicitly navigates to Delivery.
    await tester.tap(find.bySemanticsIdentifier('shell_tab_delivery'));
    await tester.pumpAndSettle();
    _expectTabSelected(tester, 'delivery', selected: true);

    // getMe now resolves the dual-role jeeber capability.
    availability.setAvailableRoles(const ['client', 'jeeber']);
    await tester.pumpAndSettle();

    // The user's explicit Delivery choice is preserved (not auto-moved to the
    // Jeeber Dashboard), while the jeeber tabs DO light up their live bodies.
    _expectTabSelected(tester, 'delivery', selected: true);
    expect(
      find.byKey(const Key('dashboard-tab-root'), skipOffstage: false),
      findsOneWidget,
    );

    handle.dispose();
  });
}
