// redesign-2026-08 §5.1 ("Not shared"): the bottom bar is restyled IN PLACE —
// 52×30 `surfaceContainerHigh` pill + navy glyph + 12/w700 label when selected,
// 22px periwinkle glyph + 12/w600 when not, a `1px outlineVariant` top rule
// instead of the old shadow, pad `12/8/26`.
//
// The board draws ONE 5-tab bar for both roles; the app's additive tab model
// wins (plan §9-Q1), so this file locks the STYLE and the `shell_tab_*`
// identifiers — never a unified role-agnostic tab list.

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
        theme: AppTheme.light(),
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

/// The glyph box of a tab — the widget that carries the selected pill.
Container _glyphBox(WidgetTester tester, String tabId) => tester.widget<Container>(
      find
          .descendant(
            of: find.bySemanticsIdentifier('shell_tab_$tabId'),
            matching: find.byType(Container),
          )
          .first,
    );

TextStyle _labelStyle(WidgetTester tester, String tabId) => tester
    .widget<Text>(
      find
          .descendant(
            of: find.bySemanticsIdentifier('shell_tab_$tabId'),
            matching: find.byType(Text),
          )
          .first,
    )
    .style!;

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

  testWidgets('the SELECTED tab wears a 52×30 surfaceContainerHigh pill and '
      'no other tab does', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await tester.pumpAndSettle();

    final scheme = AppTheme.light().colorScheme;

    // A plain client lands on Requests.
    final selected = _glyphBox(tester, 'requests');
    final decoration = selected.decoration! as BoxDecoration;
    expect(decoration.color, scheme.surfaceContainerHigh);
    expect(
      decoration.borderRadius,
      const BorderRadius.all(Radius.circular(14)),
    );
    final pillRect = tester.getRect(
      find
          .descendant(
            of: find.bySemanticsIdentifier('shell_tab_requests'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(pillRect.width, 52);
    expect(pillRect.height, 30);

    for (final id in ['delivery', 'dashboard', 'earnings', 'profile']) {
      expect(_glyphBox(tester, id).decoration, isNull,
          reason: 'only the selected tab is filled ($id was)');
    }
  });

  testWidgets('glyph + label ink: navy when selected, periwinkle otherwise, '
      'at 12/w700 vs 12/w600', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await tester.pumpAndSettle();

    final scheme = AppTheme.light().colorScheme;

    final selectedLabel = _labelStyle(tester, 'requests');
    expect(selectedLabel.color, scheme.primary);
    expect(selectedLabel.fontSize, 12);
    expect(selectedLabel.fontWeight, FontWeight.w700);

    final unselectedLabel = _labelStyle(tester, 'profile');
    expect(unselectedLabel.color, scheme.onSecondaryContainer);
    expect(unselectedLabel.fontSize, 12);
    expect(unselectedLabel.fontWeight, FontWeight.w600);

    // One filled glyph per tab at 22px — the board never swaps an outlined
    // variant in; only the ink changes.
    final glyphs = tester.widgetList<Icon>(
      find.descendant(
        of: find.bySemanticsIdentifier('shell_tab_delivery'),
        matching: find.byType(Icon),
      ),
    );
    expect(glyphs.first.size, 22);
    expect(glyphs.first.icon, Icons.local_shipping);
    expect(glyphs.first.color, scheme.onSecondaryContainer);
  });

  testWidgets('the bar is separated by a 1px outlineVariant rule, not a shadow',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('en')));
    await tester.pumpAndSettle();

    final scheme = AppTheme.light().colorScheme;
    final decorations = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.bySemanticsIdentifier('shell_tab_profile'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    final barDecoration =
        decorations.firstWhere((d) => d.border != null && d.color != null);

    expect(barDecoration.color, scheme.surface);
    expect(barDecoration.boxShadow, isNull,
        reason: 'outline over shadow — the pre-redesign top shadow is gone');
    final top = (barDecoration.border! as Border).top;
    expect(top.width, 1);
    expect(top.color, scheme.outlineVariant);
  });

  testWidgets('the bar mirrors in RTL: Requests moves to the END edge',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs, const Locale('ar')));
    await tester.pumpAndSettle();

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
