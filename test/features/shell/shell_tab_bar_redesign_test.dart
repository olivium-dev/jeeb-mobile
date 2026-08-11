// MIDNIGHT M2-01: the shell's tab bar IS the frozen kit `JeebPillNav` — a
// detached navy capsule floating over each tab's own field, orange spent only
// on the active slot. This file locks the SHELL's half of that contract (slot
// order, the frozen `shell_tab_*` identifiers, the floating framing, light
// system chrome); the capsule's own metrics are locked by
// test/core/widgets/jeeb/jeeb_pill_nav_test.dart.
//
// The app's additive tab model wins over the board's single 5-tab bar
// (plan §9-Q1) — the tabs were mapped positionally onto R1's slots, never
// unified into a role-agnostic list.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
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

Widget _harness(SharedPreferences prefs, Locale locale) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LocaleCubit(
            prefs: prefs,
            deviceLocaleProvider: () => locale,
          ),
        ),
        BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
        BlocProvider(create: (_) => RoleEligibilityCubit()),
        BlocProvider(
          create: (_) => RoleAvailabilityCubit(
            const RoleAvailability(roles: ['client']),
          ),
        ),
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
      ),
    );

/// The five slot ids, in R1's visual order.
const List<String> _kSlots = <String>[
  'requests',
  'delivery',
  'dashboard',
  'earnings',
  'profile',
];

/// M0-4 ruling: Midnight primitives loop forever, so a shell test that mounts
/// real tab bodies can only settle under reduce motion.
void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Reduce motion settles on the first frame, so the clock still has to be
/// advanced past the tab fixtures' own load delays.
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

  testWidgets('the bar IS JeebPillNav, carrying the five frozen shell_tab_ ids '
      'in R1 order', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await _settle(tester);

    final JeebPillNav nav = tester.widget<JeebPillNav>(
      find.byType(JeebPillNav),
    );
    expect(nav.items.length, JeebPillNav.slotCount);
    expect(
      nav.items.map((JeebPillNavItem i) => i.identifier),
      _kSlots.map((String id) => 'shell_tab_$id'),
    );
    // Close-out ruling: labels follow the ACTIVE ROLE — a client role never
    // reads the jeeber words "Dashboard"/"Earnings" over its invitations.
    expect(
      nav.items.map((JeebPillNavItem i) => i.label),
      const <String>[
        'Requests',
        'Delivery',
        'Deliver',
        'Earn',
        'Profile',
      ],
    );
    // A plain client lands on Requests, so slot 0 wears the orange pill.
    expect(nav.selectedIndex, 0);
  });

  testWidgets('the capsule is navy + glass hairline + floatNav shadow, and it '
      'floats — no full-width bar band', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await _settle(tester);

    final ThemeData theme = AppTheme.midnight();
    final JeebSemanticColors semantics =
        theme.extension<JeebSemanticColors>()!;

    final BoxDecoration decoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(JeebPillNav),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((BoxDecoration d) => d.boxShadow != null);

    expect(decoration.color, theme.colorScheme.surface);
    expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.pill));
    expect((decoration.border! as Border).top.color, semantics.glassBorder);
    expect(decoration.boxShadow, JeebShadows.floatNav);

    // Detached: inset from both screen edges and lifted off the bottom.
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect capsule = tester.getRect(
      find.descendant(
        of: find.byType(JeebPillNav),
        matching: find.byType(ClipRRect),
      ).first,
    );
    expect(capsule.left, 16);
    expect(screen.width - capsule.right, 16);
    expect(screen.height - capsule.bottom, greaterThanOrEqualTo(20));
  });

  testWidgets('the shell paints no field of its own and the tab content runs '
      'UNDER the floating nav', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await _settle(tester);

    final Scaffold shell = tester.widget<Scaffold>(
      find
          .ancestor(of: find.byType(JeebPillNav), matching: find.byType(Scaffold))
          .first,
    );
    expect(shell.extendBody, isTrue,
        reason: 'the nav floats OVER the tab body, it does not push it up');
    // Never a light slab between tabs: the fallback under every tab's own
    // Midnight field is the page navy, never a white scaffold.
    expect(
      shell.backgroundColor ?? AppTheme.midnight().scaffoldBackgroundColor,
      AppTheme.midnight().scaffoldBackgroundColor,
    );
  });

  testWidgets('every tab body still reserves the nav height (VIS-P1-2)',
      (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await _settle(tester);

    final BuildContext tabContext = tester.element(
      find.byType(IndexedStack),
    );
    final MediaQueryData mq = MediaQuery.of(tabContext);
    final double navHeight = tester.getSize(find.byType(JeebPillNav)).height;

    expect(mq.padding.bottom, greaterThanOrEqualTo(navHeight));
    expect(mq.viewPadding.bottom, mq.padding.bottom,
        reason: 'scrollBodyBottomInset reads viewPadding — it must clear too');
  });

  testWidgets('system chrome stays LIGHT over every tab', (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await _settle(tester);

    for (final String id in _kSlots) {
      await tester.tap(find.bySemanticsIdentifier('shell_tab_$id'));
      await _settle(tester);

      final Iterable<SystemUiOverlayStyle> styles = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .map((AnnotatedRegion<SystemUiOverlayStyle> r) => r.value);

      expect(styles, isNotEmpty, reason: '$id declares no overlay style');
      for (final SystemUiOverlayStyle style in styles) {
        expect(style.statusBarIconBrightness, Brightness.light,
            reason: '$id darkens the status glyphs over navy');
      }
    }
  });

  testWidgets('the nav mirrors in RTL: Requests moves to the END edge',
      (tester) async {
    _reduceMotion(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('ar')));
    await _settle(tester);

    final requests = tester.getRect(
      find.bySemanticsIdentifier('shell_tab_requests'),
    );
    final profile = tester.getRect(
      find.bySemanticsIdentifier('shell_tab_profile'),
    );
    expect(requests.left, greaterThan(profile.left),
        reason: 'RTL puts the first destination on the right');
    // Equal fifths either way, so the geometry itself never mirrors wrong.
    expect(requests.width, moreOrLessEquals(profile.width, epsilon: 0.01));
  });
}
