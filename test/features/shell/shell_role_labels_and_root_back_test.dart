// Close-out small-defect batch (2026-08-11):
//   * the pill-nav LABELS follow the ACTIVE ROLE (a client never reads the
//     jeeber words; a jeeber's "Requests" names the incoming feed and the
//     client compose surface becomes "My Requests");
//   * hardware BACK at the shell root no longer destroys the task on the first
//     press.
// The frozen `shell_tab_*` identifiers and the slot ORDER are unchanged — those
// stay locked by shell_tab_bar_redesign_test.dart.

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
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pill_nav.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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

Widget _harness(SharedPreferences prefs, {required UserRole role}) =>
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LocaleCubit(
            prefs: prefs,
            deviceLocaleProvider: () => const Locale('en'),
          ),
        ),
        BlocProvider(
          create: (_) => RoleCubit(prefs: prefs, initialRole: role),
        ),
        BlocProvider(create: (_) => RoleEligibilityCubit()),
        // Capabilities stay CLIENT-only on purpose: the labels must follow the
        // active role without the live jeeber bodies being mounted.
        BlocProvider(
          create: (_) => RoleAvailabilityCubit(
            const RoleAvailability(roles: ['client']),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.midnight(),
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

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

List<String> _labels(WidgetTester tester) => tester
    .widget<JeebPillNav>(find.byType(JeebPillNav))
    .items
    .map((JeebPillNavItem i) => i.label)
    .toList();

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

  testWidgets('client role: no jeeber wording anywhere in the nav',
      (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    expect(_labels(tester), const <String>[
      'Requests',
      'Delivery',
      'Deliver',
      'Earn',
      'Profile',
    ]);
  });

  testWidgets('jeeber role: "Requests" names the incoming feed slot, and the '
      'client compose surface becomes "My Requests"', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.jeeber));
    await _settle(tester);

    final labels = _labels(tester);
    expect(labels, const <String>[
      'My Requests',
      'Deliveries',
      'Requests',
      'Earnings',
      'Profile',
    ]);
    // The frozen ids did NOT move with the wording.
    expect(
      tester
          .widget<JeebPillNav>(find.byType(JeebPillNav))
          .items
          .map((JeebPillNavItem i) => i.identifier),
      const <String>[
        'shell_tab_requests',
        'shell_tab_delivery',
        'shell_tab_dashboard',
        'shell_tab_earnings',
        'shell_tab_profile',
      ],
    );
  });

  testWidgets('root BACK returns to the landing tab instead of exiting',
      (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
    await _settle(tester);
    expect(
      tester.widget<JeebPillNav>(find.byType(JeebPillNav)).selectedIndex,
      4,
    );

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(
      tester.widget<JeebPillNav>(find.byType(JeebPillNav)).selectedIndex,
      0,
    );
    // The shell is still mounted — the first BACK never tore the task down.
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('BACK on the landing tab warns first rather than exiting',
      (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('the /settings hub has exactly one in-app entry: the Profile-tab '
      'gear', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, role: UserRole.client));
    await _settle(tester);

    // The Requests tab keeps its two header actions and gains no gear.
    expect(
      find.bySemanticsIdentifier('orders_home_wallet_chip'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('orders_home_settings'), findsNothing);

    await tester.tap(find.bySemanticsIdentifier('shell_tab_profile'));
    await _settle(tester);
    expect(
      find.bySemanticsIdentifier('customer_profile_settings'),
      findsOneWidget,
    );
  });
}
